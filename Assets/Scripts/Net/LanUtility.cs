using System;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using UnityEngine;

namespace BattleOfAgents.Core
{
    /// <summary>Small helpers for the Wi-Fi/LAN layer: which address are we on, and
    /// which broadcast address should the host beacon target.</summary>
    public static class LanUtility
    {
        /// <summary>The device's IPv4 address on the current Wi-Fi network,
        /// or "0.0.0.0" when not on a LAN.</summary>
        public static string LocalIPv4()
        {
            try
            {
                foreach (var nic in NetworkInterface.GetAllNetworkInterfaces())
                {
                    if (nic.OperationalStatus != OperationalStatus.Up) continue;
                    if (nic.NetworkInterfaceType == NetworkInterfaceType.Loopback) continue;

                    foreach (var addr in nic.GetIPProperties().UnicastAddresses)
                    {
                        if (addr.Address.AddressFamily != AddressFamily.InterNetwork) continue;
                        var ip = addr.Address.ToString();
                        if (ip.StartsWith("169.254")) continue;   // link-local, no DHCP
                        return ip;
                    }
                }
            }
            catch (Exception e)
            {
                Debug.LogWarning("[LAN] address lookup failed: " + e.Message);
            }
            return "0.0.0.0";
        }

        /// <summary>Directed broadcast address for the current subnet — more reliable
        /// than 255.255.255.255 on Android, which some routers drop.</summary>
        public static IPAddress BroadcastAddress()
        {
            try
            {
                foreach (var nic in NetworkInterface.GetAllNetworkInterfaces())
                {
                    if (nic.OperationalStatus != OperationalStatus.Up) continue;
                    if (nic.NetworkInterfaceType == NetworkInterfaceType.Loopback) continue;

                    foreach (var addr in nic.GetIPProperties().UnicastAddresses)
                    {
                        if (addr.Address.AddressFamily != AddressFamily.InterNetwork) continue;
                        if (addr.IPv4Mask == null) continue;

                        var ipBytes = addr.Address.GetAddressBytes();
                        var maskBytes = addr.IPv4Mask.GetAddressBytes();
                        var broadcast = new byte[4];
                        for (int i = 0; i < 4; i++)
                            broadcast[i] = (byte)(ipBytes[i] | (maskBytes[i] ^ 255));
                        return new IPAddress(broadcast);
                    }
                }
            }
            catch (Exception e)
            {
                Debug.LogWarning("[LAN] broadcast lookup failed: " + e.Message);
            }
            return IPAddress.Broadcast;
        }

        public static bool IsOnWifi()
        {
            return Application.internetReachability == NetworkReachability.ReachableViaLocalAreaNetwork;
        }
    }
}
