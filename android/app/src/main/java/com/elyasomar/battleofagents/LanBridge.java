package com.elyasomar.battleofagents;

import android.content.Context;
import android.net.wifi.WifiManager;
import android.util.Log;
import android.webkit.JavascriptInterface;

import org.json.JSONArray;
import org.json.JSONObject;

import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.net.InterfaceAddress;
import java.net.NetworkInterface;
import java.nio.charset.StandardCharsets;
import java.util.Collections;
import java.util.Enumeration;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Wi-Fi room discovery, exposed to the game's JavaScript as {@code window.BoaLan}.
 *
 * Same wire format as the Unity build: a small JSON beacon broadcast once a
 * second on UDP 47777, so a phone running this APK and a phone running the Unity
 * build see each other's rooms. A multicast lock is held while scanning because
 * Android drops broadcast packets to sleeping apps without one.
 */
public class LanBridge {

    private static final String TAG = "BoaLan";
    private static final String PROTOCOL = "BOA1";
    private static final int DISCOVERY_PORT = 47777;
    private static final int GAME_PORT = 47778;
    private static final long ROOM_TIMEOUT_MS = 4000;
    private static final long BEACON_INTERVAL_MS = 1000;

    private final Context context;
    private final Map<String, JSONObject> rooms = Collections.synchronizedMap(new LinkedHashMap<>());

    private volatile boolean scanning;
    private volatile boolean hosting;
    private DatagramSocket listenSocket;
    private DatagramSocket beaconSocket;
    private WifiManager.MulticastLock multicastLock;
    private JSONObject beacon;

    public LanBridge(Context context) {
        this.context = context.getApplicationContext();
    }

    // --- called from JavaScript ------------------------------------------------

    @JavascriptInterface
    public void startScan() {
        if (scanning) return;
        scanning = true;
        acquireMulticastLock();

        new Thread(() -> {
            try {
                listenSocket = new DatagramSocket(null);
                listenSocket.setReuseAddress(true);
                listenSocket.setBroadcast(true);
                listenSocket.bind(new java.net.InetSocketAddress(DISCOVERY_PORT));

                byte[] buffer = new byte[2048];
                while (scanning) {
                    DatagramPacket packet = new DatagramPacket(buffer, buffer.length);
                    listenSocket.receive(packet);
                    onBeacon(new String(packet.getData(), 0, packet.getLength(), StandardCharsets.UTF_8),
                            packet.getAddress().getHostAddress());
                }
            } catch (Exception e) {
                if (scanning) Log.w(TAG, "scan stopped: " + e.getMessage());
            } finally {
                closeQuietly(listenSocket);
            }
        }, "boa-lan-scan").start();
    }

    @JavascriptInterface
    public void stopScan() {
        scanning = false;
        closeQuietly(listenSocket);
        releaseMulticastLock();
    }

    /** Starts advertising a room on this network. */
    @JavascriptInterface
    public void hostRoom(String roomName, String mapName, int maxPlayers) {
        stopHost();
        try {
            beacon = new JSONObject()
                    .put("proto", PROTOCOL)
                    .put("roomId", UUID.randomUUID().toString().substring(0, 8))
                    .put("roomName", roomName)
                    .put("hostName", android.os.Build.MODEL)
                    .put("port", GAME_PORT)
                    .put("players", 1)
                    .put("maxPlayers", maxPlayers)
                    .put("mode", 0)
                    .put("map", mapName)
                    .put("locked", false);
        } catch (Exception e) {
            Log.e(TAG, "cannot build beacon", e);
            return;
        }

        hosting = true;
        new Thread(() -> {
            try {
                beaconSocket = new DatagramSocket();
                beaconSocket.setBroadcast(true);

                while (hosting) {
                    byte[] payload = beacon.toString().getBytes(StandardCharsets.UTF_8);
                    for (InetAddress target : broadcastAddresses()) {
                        try {
                            beaconSocket.send(new DatagramPacket(payload, payload.length,
                                    target, DISCOVERY_PORT));
                        } catch (Exception ignored) {
                            // one dead interface should not stop the others
                        }
                    }
                    Thread.sleep(BEACON_INTERVAL_MS);
                }
            } catch (Exception e) {
                if (hosting) Log.w(TAG, "beacon stopped: " + e.getMessage());
            } finally {
                closeQuietly(beaconSocket);
            }
        }, "boa-lan-beacon").start();
    }

    @JavascriptInterface
    public void stopHost() {
        hosting = false;
        closeQuietly(beaconSocket);
    }

    /** The room list as JSON, oldest-seen first. Stale rooms are dropped here. */
    @JavascriptInterface
    public String rooms() {
        long now = System.currentTimeMillis();
        JSONArray array = new JSONArray();

        synchronized (rooms) {
            rooms.entrySet().removeIf(entry ->
                    now - entry.getValue().optLong("seenAt", 0) > ROOM_TIMEOUT_MS);
            for (JSONObject room : rooms.values()) array.put(room);
        }
        return array.toString();
    }

    @JavascriptInterface
    public String localIp() {
        try {
            for (Enumeration<NetworkInterface> nics = NetworkInterface.getNetworkInterfaces();
                 nics.hasMoreElements(); ) {
                NetworkInterface nic = nics.nextElement();
                if (nic.isLoopback() || !nic.isUp()) continue;

                for (InterfaceAddress address : nic.getInterfaceAddresses()) {
                    InetAddress ip = address.getAddress();
                    if (ip instanceof java.net.Inet4Address && !ip.isLoopbackAddress())
                        return ip.getHostAddress();
                }
            }
        } catch (Exception e) {
            Log.w(TAG, "no address: " + e.getMessage());
        }
        return "0.0.0.0";
    }

    @JavascriptInterface
    public boolean isHosting() { return hosting; }

    // --- internals --------------------------------------------------------------

    private void onBeacon(String json, String senderIp) {
        try {
            JSONObject message = new JSONObject(json);
            if (!PROTOCOL.equals(message.optString("proto"))) return;

            message.put("hostAddress", senderIp);
            message.put("seenAt", System.currentTimeMillis());
            rooms.put(message.optString("roomId", senderIp), message);
        } catch (Exception e) {
            Log.w(TAG, "bad beacon from " + senderIp);
        }
    }

    /**
     * Directed broadcast per interface. 255.255.255.255 is dropped by a fair
     * number of consumer routers, so the subnet address is the reliable target.
     */
    private java.util.List<InetAddress> broadcastAddresses() {
        java.util.List<InetAddress> targets = new java.util.ArrayList<>();
        try {
            for (Enumeration<NetworkInterface> nics = NetworkInterface.getNetworkInterfaces();
                 nics.hasMoreElements(); ) {
                NetworkInterface nic = nics.nextElement();
                if (nic.isLoopback() || !nic.isUp()) continue;

                for (InterfaceAddress address : nic.getInterfaceAddresses()) {
                    InetAddress broadcast = address.getBroadcast();
                    if (broadcast != null) targets.add(broadcast);
                }
            }
        } catch (Exception e) {
            Log.w(TAG, "no broadcast address: " + e.getMessage());
        }
        if (targets.isEmpty()) {
            try { targets.add(InetAddress.getByName("255.255.255.255")); }
            catch (Exception ignored) { }
        }
        return targets;
    }

    private void acquireMulticastLock() {
        try {
            WifiManager wifi = (WifiManager) context.getSystemService(Context.WIFI_SERVICE);
            if (wifi == null) return;
            multicastLock = wifi.createMulticastLock("boa-discovery");
            multicastLock.setReferenceCounted(true);
            multicastLock.acquire();
        } catch (Exception e) {
            Log.w(TAG, "no multicast lock: " + e.getMessage());
        }
    }

    private void releaseMulticastLock() {
        try {
            if (multicastLock != null && multicastLock.isHeld()) multicastLock.release();
        } catch (Exception ignored) { }
        multicastLock = null;
    }

    private static void closeQuietly(DatagramSocket socket) {
        if (socket != null && !socket.isClosed()) socket.close();
    }

    public void shutdown() {
        stopScan();
        stopHost();
    }
}
