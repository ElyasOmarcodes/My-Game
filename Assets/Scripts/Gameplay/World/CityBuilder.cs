using System.Collections.Generic;
using BattleOfAgents.Core;
using BattleOfAgents.Gameplay.Models;
using UnityEngine;

namespace BattleOfAgents.Gameplay.World
{
    public enum District { Downtown, Residential, Industrial, Park, Waterfront }

    /// <summary>Generates the open-world map: a ~460 m city of streets, blocks and
    /// districts, from a single integer seed.
    ///
    /// Procedural generation is what makes this affordable. The host sends four bytes
    /// and every phone builds the identical city — no level file to download, nothing
    /// in the APK, and no risk of two players standing in different worlds. Geometry
    /// is merged per material as it is generated, so the whole city ends up as roughly
    /// a dozen meshes rather than thousands of objects.</summary>
    public class CityBuilder : MonoBehaviour
    {
        public const int BlocksPerSide = 6;
        public const float BlockSize = 58f;
        public const float RoadWidth = 16f;
        public const float SidewalkHeight = 0.16f;
        public const float SidewalkInset = 3.4f;

        public static float Span { get { return BlocksPerSide * BlockSize + (BlocksPerSide + 1) * RoadWidth; } }

        public readonly List<Transform> Spawns = new List<Transform>();
        public string MapName { get; private set; }

        System.Random _random;

        // one builder per material — everything merges into these
        BoxMeshBuilder _asphalt, _pavement, _concrete, _brick, _steel, _glass,
                       _grass, _foliage, _bark, _water, _marking,
                       _windowsWarm, _windowsCool, _lamps, _neonCyan, _neonAmber, _neonPink;

        readonly List<Bounds> _colliderBoxes = new List<Bounds>();

        public void Build(int seed, string mapName)
        {
            MapName = mapName;
            _random = new System.Random(seed);
            gameObject.name = "[City] " + mapName;

            NewBuilders();
            Lighting();
            Ground();

            for (int gx = 0; gx < BlocksPerSide; gx++)
            for (int gz = 0; gz < BlocksPerSide; gz++)
                BuildBlock(gx, gz);

            Streets();
            EmitAll();
            EmitColliders();
            PlaceSpawns();

            Debug.Log("[City] " + mapName + " built · " + Span.ToString("0") + "m across · " +
                      _colliderBoxes.Count + " colliders");
        }

        void NewBuilders()
        {
            _asphalt = new BoxMeshBuilder(); _pavement = new BoxMeshBuilder();
            _concrete = new BoxMeshBuilder(); _brick = new BoxMeshBuilder();
            _steel = new BoxMeshBuilder(); _glass = new BoxMeshBuilder();
            _grass = new BoxMeshBuilder(); _foliage = new BoxMeshBuilder();
            _bark = new BoxMeshBuilder(); _water = new BoxMeshBuilder();
            _marking = new BoxMeshBuilder(); _windowsWarm = new BoxMeshBuilder();
            _windowsCool = new BoxMeshBuilder(); _lamps = new BoxMeshBuilder();
            _neonCyan = new BoxMeshBuilder(); _neonAmber = new BoxMeshBuilder();
            _neonPink = new BoxMeshBuilder();
        }

        // --- lighting ---------------------------------------------------------

        void Lighting()
        {
            var sunGo = new GameObject("KeyLight");
            sunGo.transform.SetParent(transform, false);
            sunGo.transform.rotation = Quaternion.Euler(34f, 42f, 0f);   // low sun: long shadows
            var sun = sunGo.AddComponent<Light>();
            sun.type = LightType.Directional;
            sun.color = new Color(1f, 0.80f, 0.62f);
            sun.intensity = 1.15f;
            sun.shadows = LightShadows.Soft;
            sun.shadowStrength = 0.8f;

            var fillGo = new GameObject("SkyFill");
            fillGo.transform.SetParent(transform, false);
            fillGo.transform.rotation = Quaternion.Euler(-22f, -128f, 0f);
            var fill = fillGo.AddComponent<Light>();
            fill.type = LightType.Directional;
            fill.color = new Color(0.38f, 0.60f, 0.95f);
            fill.intensity = 0.5f;
            fill.shadows = LightShadows.None;

            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = new Color(0.13f, 0.18f, 0.26f);
            RenderSettings.ambientEquatorColor = new Color(0.07f, 0.09f, 0.13f);
            RenderSettings.ambientGroundColor = new Color(0.025f, 0.028f, 0.035f);
            RenderSettings.fog = true;
            RenderSettings.fogMode = FogMode.ExponentialSquared;
            RenderSettings.fogColor = new Color(0.055f, 0.075f, 0.115f);
            RenderSettings.fogDensity = 0.0055f;   // aerial haze: depth without hiding the city
        }

        // --- ground and streets ------------------------------------------------

        void Ground()
        {
            var half = Span * 0.5f;
            _asphalt.Add(new Vector3(0f, -0.25f, 0f), new Vector3(Span + 60f, 0.5f, Span + 60f));

            var ground = new GameObject("GroundCollider");
            ground.transform.SetParent(transform, false);
            var box = ground.AddComponent<BoxCollider>();
            box.center = new Vector3(0f, -0.25f, 0f);
            box.size = new Vector3(Span + 60f, 0.5f, Span + 60f);

            // Water on the south edge — the city reads as a waterfront town, and it
            // stops the map feeling like it was cut with scissors.
            _water.Add(new Vector3(0f, -0.10f, -half - 26f), new Vector3(Span + 60f, 0.3f, 44f));
        }

        void Streets()
        {
            var half = Span * 0.5f;

            for (int i = 0; i <= BlocksPerSide; i++)
            {
                var offset = -half + RoadWidth * 0.5f + i * (BlockSize + RoadWidth);

                // lane markings down the middle of every road
                for (float t = -half; t < half; t += 8f)
                {
                    _marking.Add(new Vector3(offset, 0.02f, t + 2f), new Vector3(0.35f, 0.02f, 3.4f));
                    _marking.Add(new Vector3(t + 2f, 0.02f, offset), new Vector3(3.4f, 0.02f, 0.35f));
                }

                // streetlights, alternating sides
                for (int j = 0; j < BlocksPerSide; j++)
                {
                    var along = -half + RoadWidth + j * (BlockSize + RoadWidth) + BlockSize * 0.5f;
                    StreetLight(new Vector3(offset - RoadWidth * 0.42f, 0f, along), 90f);
                    StreetLight(new Vector3(along, 0f, offset + RoadWidth * 0.42f), 0f);
                }
            }
        }

        void StreetLight(Vector3 basePosition, float yaw)
        {
            const float poleHeight = 7.2f;
            _steel.Add(basePosition + new Vector3(0f, poleHeight * 0.5f, 0f),
                new Vector3(0.22f, poleHeight, 0.22f));

            var armDirection = Quaternion.Euler(0f, yaw, 0f) * Vector3.forward;
            var headPosition = basePosition + new Vector3(0f, poleHeight, 0f) + armDirection * 1.3f;

            _steel.Add(basePosition + new Vector3(0f, poleHeight - 0.1f, 0f) + armDirection * 0.7f,
                new Vector3(0.14f, 0.14f, 1.5f), yaw);
            _lamps.Add(headPosition + new Vector3(0f, -0.18f, 0f), new Vector3(0.55f, 0.14f, 0.95f), yaw);
        }

        // --- blocks -------------------------------------------------------------

        Vector3 BlockCentre(int gx, int gz)
        {
            var half = Span * 0.5f;
            var step = BlockSize + RoadWidth;
            return new Vector3(
                -half + RoadWidth + BlockSize * 0.5f + gx * step, 0f,
                -half + RoadWidth + BlockSize * 0.5f + gz * step);
        }

        District DistrictFor(int gx, int gz)
        {
            var mid = (BlocksPerSide - 1) * 0.5f;
            var distance = Mathf.Max(Mathf.Abs(gx - mid), Mathf.Abs(gz - mid));

            if (gx == 1 && gz == 3) return District.Park;
            if (gz == 0) return District.Waterfront;
            if (gx >= BlocksPerSide - 2 && gz <= 1) return District.Industrial;
            return distance <= 1f ? District.Downtown : District.Residential;
        }

        void BuildBlock(int gx, int gz)
        {
            var centre = BlockCentre(gx, gz);
            var district = DistrictFor(gx, gz);

            // sidewalk slab, slightly larger than the lots on it
            _pavement.Add(centre + new Vector3(0f, SidewalkHeight * 0.5f, 0f),
                new Vector3(BlockSize, SidewalkHeight, BlockSize));

            switch (district)
            {
                case District.Park:       BuildPark(centre); break;
                case District.Industrial: BuildIndustrial(centre); break;
                case District.Waterfront: BuildWaterfront(centre); break;
                case District.Downtown:   BuildLots(centre, 26f, 58f, true); break;
                default:                  BuildLots(centre, 9f, 22f, false); break;
            }
        }

        /// <summary>Splits a block into 2x2 lots and puts a building on each, leaving a
        /// gap for the sidewalk. Uneven lot sizes keep the skyline from looking stamped.</summary>
        void BuildLots(Vector3 centre, float minHeight, float maxHeight, bool downtown)
        {
            var usable = BlockSize - SidewalkInset * 2f;
            var split = usable * (0.38f + (float)_random.NextDouble() * 0.24f);

            var lots = new[]
            {
                new Vector4(-usable * 0.5f, -usable * 0.5f, split, split),
                new Vector4(-usable * 0.5f + split, -usable * 0.5f, usable - split, split),
                new Vector4(-usable * 0.5f, -usable * 0.5f + split, split, usable - split),
                new Vector4(-usable * 0.5f + split, -usable * 0.5f + split, usable - split, usable - split),
            };

            for (int i = 0; i < lots.Length; i++)
            {
                var lot = lots[i];
                var gap = 1.2f;
                var w = lot.z - gap;
                var d = lot.w - gap;
                if (w < 6f || d < 6f) continue;

                var position = centre + new Vector3(lot.x + lot.z * 0.5f, 0f, lot.y + lot.w * 0.5f);
                var height = minHeight + (float)_random.NextDouble() * (maxHeight - minHeight);
                Building(position, new Vector2(w, d), height, downtown);
            }
        }

        void Building(Vector3 position, Vector2 footprint, float height, bool downtown)
        {
            var glassy = downtown && _random.NextDouble() > 0.35;
            var shell = glassy ? _glass : (downtown ? _concrete : _brick);

            var baseHeight = height;
            var setback = downtown && height > 34f && _random.NextDouble() > 0.4;
            if (setback) baseHeight = height * (0.55f + (float)_random.NextDouble() * 0.2f);

            shell.Add(position + new Vector3(0f, baseHeight * 0.5f + SidewalkHeight, 0f),
                new Vector3(footprint.x, baseHeight, footprint.y));
            _colliderBoxes.Add(new Bounds(
                position + new Vector3(0f, baseHeight * 0.5f + SidewalkHeight, 0f),
                new Vector3(footprint.x, baseHeight, footprint.y)));

            Windows(position, footprint, SidewalkHeight, baseHeight, glassy);

            if (setback)
            {
                var towerFootprint = footprint * 0.62f;
                var towerHeight = height - baseHeight;
                var towerCentre = position + new Vector3(0f, baseHeight + towerHeight * 0.5f + SidewalkHeight, 0f);

                shell.Add(towerCentre, new Vector3(towerFootprint.x, towerHeight, towerFootprint.y));
                _colliderBoxes.Add(new Bounds(towerCentre,
                    new Vector3(towerFootprint.x, towerHeight, towerFootprint.y)));
                Windows(position, towerFootprint, baseHeight + SidewalkHeight, towerHeight, glassy);

                // aircraft warning light
                _neonPink.Add(position + new Vector3(0f, height + SidewalkHeight + 0.3f, 0f),
                    new Vector3(0.5f, 0.5f, 0.5f));
            }

            // A darker cap so roofs separate from facades when seen from above.
            _concrete.Add(position + new Vector3(0f, height + SidewalkHeight + 0.12f, 0f),
                new Vector3(footprint.x + 0.25f, 0.24f, footprint.y + 0.25f));
            RoofClutter(position, footprint, height + SidewalkHeight + 0.24f);
            if (downtown && _random.NextDouble() > 0.55) NeonSign(position, footprint, baseHeight);
        }

        /// <summary>Emissive strips standing in for lit windows. A few rows are left
        /// dark at random, which is what stops a facade reading as a texture swatch.</summary>
        void Windows(Vector3 position, Vector2 footprint, float from, float height, bool cool)
        {
            var builder = cool ? _windowsCool : _windowsWarm;
            const float floorHeight = 3.4f;
            var floors = Mathf.FloorToInt(height / floorHeight);

            for (int floor = 1; floor < floors; floor++)
            {
                if (_random.NextDouble() < 0.22) continue;      // dark floor
                var y = from + floor * floorHeight;

                for (int side = 0; side < 4; side++)
                {
                    if (_random.NextDouble() < 0.18) continue;  // dark face

                    var alongX = side < 2;
                    var length = (alongX ? footprint.x : footprint.y) - 1.4f;
                    if (length < 2f) continue;

                    var offset = (alongX ? footprint.y : footprint.x) * 0.5f + 0.03f;
                    var sign = side % 2 == 0 ? 1f : -1f;

                    // Split the row into panes with piers between them: one strip
                    // the width of the facade reads as a light bar, not as windows.
                    var panes = Mathf.Max(1, Mathf.RoundToInt(length / 3.4f));
                    var pitch = length / panes;
                    var paneWidth = pitch * 0.62f;

                    for (int pane = 0; pane < panes; pane++)
                    {
                        if (_random.NextDouble() < 0.25) continue;   // a dark room here and there
                        var along = -length * 0.5f + pitch * (pane + 0.5f);

                        var centre = alongX
                            ? position + new Vector3(along, y, offset * sign)
                            : position + new Vector3(offset * sign, y, along);

                        var size = alongX
                            ? new Vector3(paneWidth, 1.35f, 0.06f)
                            : new Vector3(0.06f, 1.35f, paneWidth);

                        builder.Add(centre, size);
                    }
                }
            }
        }

        void RoofClutter(Vector3 position, Vector2 footprint, float roofY)
        {
            var units = 1 + _random.Next(3);
            for (int i = 0; i < units; i++)
            {
                var x = ((float)_random.NextDouble() - 0.5f) * (footprint.x - 3f);
                var z = ((float)_random.NextDouble() - 0.5f) * (footprint.y - 3f);
                var w = 1.4f + (float)_random.NextDouble() * 2.2f;
                var h = 0.8f + (float)_random.NextDouble() * 1.6f;
                _steel.Add(position + new Vector3(x, roofY + h * 0.5f, z), new Vector3(w, h, w));
            }

            if (_random.NextDouble() > 0.6)
            {
                var mastHeight = 3f + (float)_random.NextDouble() * 5f;
                _steel.Add(position + new Vector3(0f, roofY + mastHeight * 0.5f, 0f),
                    new Vector3(0.18f, mastHeight, 0.18f));
                _neonPink.Add(position + new Vector3(0f, roofY + mastHeight + 0.2f, 0f),
                    new Vector3(0.34f, 0.34f, 0.34f));
            }
        }

        void NeonSign(Vector3 position, Vector2 footprint, float height)
        {
            var builder = _random.NextDouble() > 0.5 ? _neonCyan : _neonAmber;
            var y = 6f + (float)_random.NextDouble() * Mathf.Max(2f, height - 10f);
            var vertical = _random.NextDouble() > 0.5;

            var offset = footprint.y * 0.5f + 0.25f;
            builder.Add(position + new Vector3(0f, y, offset),
                vertical ? new Vector3(0.9f, 5.5f, 0.25f) : new Vector3(6.5f, 1.1f, 0.25f));
        }

        // --- special districts ---------------------------------------------------

        void BuildPark(Vector3 centre)
        {
            var size = BlockSize - 3f;
            _grass.Add(centre + new Vector3(0f, SidewalkHeight + 0.06f, 0f),
                new Vector3(size, 0.12f, size));

            // pond
            _water.Add(centre + new Vector3(6f, SidewalkHeight + 0.10f, -5f), new Vector3(18f, 0.14f, 13f));

            // paths crossing the park
            _pavement.Add(centre + new Vector3(0f, SidewalkHeight + 0.13f, 12f), new Vector3(size, 0.05f, 3f));
            _pavement.Add(centre + new Vector3(-14f, SidewalkHeight + 0.13f, 0f), new Vector3(3f, 0.05f, size));

            for (int i = 0; i < 16; i++)
            {
                var x = ((float)_random.NextDouble() - 0.5f) * (size - 6f);
                var z = ((float)_random.NextDouble() - 0.5f) * (size - 6f);
                if (x > -2f && x < 14f && z > -12f && z < 2f) continue;   // keep the pond clear
                Tree(centre + new Vector3(x, SidewalkHeight, z));
            }

            for (int i = 0; i < 5; i++)
                _steel.Add(centre + new Vector3(-14f, SidewalkHeight + 0.45f, -20f + i * 10f),
                    new Vector3(1.8f, 0.12f, 0.6f));                       // benches
        }

        void Tree(Vector3 basePosition)
        {
            var height = 4.5f + (float)_random.NextDouble() * 3.5f;
            _bark.Add(basePosition + new Vector3(0f, height * 0.35f, 0f),
                new Vector3(0.4f, height * 0.7f, 0.4f));

            var canopy = 2.6f + (float)_random.NextDouble() * 1.8f;
            _foliage.Add(basePosition + new Vector3(0f, height * 0.78f, 0f),
                new Vector3(canopy, canopy * 0.75f, canopy), (float)_random.NextDouble() * 45f);
            _foliage.Add(basePosition + new Vector3(0f, height * 1.02f, 0f),
                new Vector3(canopy * 0.7f, canopy * 0.55f, canopy * 0.7f),
                (float)_random.NextDouble() * 45f);
        }

        void BuildIndustrial(Vector3 centre)
        {
            var w = BlockSize - 10f;
            var d = BlockSize * 0.5f;

            // warehouse with a saw-tooth roof
            _steel.Add(centre + new Vector3(0f, 5f + SidewalkHeight, 8f), new Vector3(w, 10f, d));
            _colliderBoxes.Add(new Bounds(centre + new Vector3(0f, 5f + SidewalkHeight, 8f),
                new Vector3(w, 10f, d)));

            for (int i = 0; i < 5; i++)
                _steel.Add(centre + new Vector3(-w * 0.4f + i * (w * 0.2f), 10.6f + SidewalkHeight, 8f),
                    new Vector3(w * 0.16f, 1.4f, d), 0f);

            _windowsCool.Add(centre + new Vector3(0f, 7.5f + SidewalkHeight, 8f - d * 0.5f - 0.05f),
                new Vector3(w - 6f, 1.2f, 0.06f));

            // shipping containers in the yard
            var colours = new[] { _brick, _steel, _concrete };
            for (int i = 0; i < 9; i++)
            {
                var x = ((float)_random.NextDouble() - 0.5f) * (w - 8f);
                var z = -14f + (float)_random.NextDouble() * 10f;
                var stacked = _random.NextDouble() > 0.6;
                var yaw = _random.NextDouble() > 0.5 ? 0f : 90f;

                var builder = colours[_random.Next(colours.Length)];
                builder.Add(centre + new Vector3(x, 1.3f + SidewalkHeight, z), new Vector3(6.1f, 2.6f, 2.4f), yaw);
                if (stacked)
                    builder.Add(centre + new Vector3(x, 3.9f + SidewalkHeight, z), new Vector3(6.1f, 2.6f, 2.4f), yaw);

                _colliderBoxes.Add(new Bounds(centre + new Vector3(x, (stacked ? 2.6f : 1.3f) + SidewalkHeight, z),
                    new Vector3(6.4f, stacked ? 5.2f : 2.6f, 6.4f)));
            }

            _neonAmber.Add(centre + new Vector3(0f, 11.6f + SidewalkHeight, 8f), new Vector3(7f, 0.9f, 0.3f));
        }

        void BuildWaterfront(Vector3 centre)
        {
            // low warehouses and a promenade facing the water
            _pavement.Add(centre + new Vector3(0f, SidewalkHeight + 0.08f, -BlockSize * 0.32f),
                new Vector3(BlockSize - 4f, 0.1f, BlockSize * 0.3f));

            for (int i = 0; i < 2; i++)
            {
                var w = BlockSize * 0.42f;
                var x = -BlockSize * 0.24f + i * BlockSize * 0.48f;
                var height = 7f + (float)_random.NextDouble() * 6f;
                var position = centre + new Vector3(x, 0f, BlockSize * 0.18f);

                _brick.Add(position + new Vector3(0f, height * 0.5f + SidewalkHeight, 0f),
                    new Vector3(w, height, BlockSize * 0.34f));
                _colliderBoxes.Add(new Bounds(position + new Vector3(0f, height * 0.5f + SidewalkHeight, 0f),
                    new Vector3(w, height, BlockSize * 0.34f)));
                Windows(position, new Vector2(w, BlockSize * 0.34f), SidewalkHeight, height, false);
            }

            for (int i = 0; i < 4; i++)
                _steel.Add(centre + new Vector3(-20f + i * 13f, SidewalkHeight + 0.6f, -BlockSize * 0.45f),
                    new Vector3(1.2f, 1.2f, 1.2f));      // bollards
        }

        // --- emit ----------------------------------------------------------------

        void EmitAll()
        {
            _asphalt.Emit(transform, "Roads", MaterialLibrary.Asphalt);
            _pavement.Emit(transform, "Sidewalks", MaterialLibrary.Pavement);
            _marking.Emit(transform, "LaneMarkings", MaterialLibrary.RoadMarking);
            _concrete.Emit(transform, "Concrete", MaterialLibrary.Concrete);
            _brick.Emit(transform, "Brick", MaterialLibrary.Brick);
            _steel.Emit(transform, "Steel", MaterialLibrary.Steel);
            _glass.Emit(transform, "Glass", MaterialLibrary.Glass);
            _grass.Emit(transform, "Grass", MaterialLibrary.Grass);
            _foliage.Emit(transform, "Foliage", MaterialLibrary.Foliage);
            _bark.Emit(transform, "Trunks", MaterialLibrary.Bark);
            _water.Emit(transform, "Water", MaterialLibrary.Water);
            _windowsWarm.Emit(transform, "WindowsWarm", MaterialLibrary.Windows);
            _windowsCool.Emit(transform, "WindowsCool", MaterialLibrary.WindowsCool);
            _lamps.Emit(transform, "StreetLights", MaterialLibrary.StreetLight);
            _neonCyan.Emit(transform, "NeonCyan", MaterialLibrary.NeonCyan);
            _neonAmber.Emit(transform, "NeonAmber", MaterialLibrary.NeonAmber);
            _neonPink.Emit(transform, "NeonPink", MaterialLibrary.NeonPink);
        }

        /// <summary>Box colliders, not a mesh collider: a weapon raycast against a few
        /// hundred boxes is far cheaper than against a hundred thousand triangles.</summary>
        void EmitColliders()
        {
            var host = new GameObject("Collision");
            host.transform.SetParent(transform, false);

            for (int i = 0; i < _colliderBoxes.Count; i++)
            {
                var box = host.AddComponent<BoxCollider>();
                box.center = _colliderBoxes[i].center;
                box.size = _colliderBoxes[i].size;
            }
        }

        void PlaceSpawns()
        {
            var half = Span * 0.5f;
            var step = BlockSize + RoadWidth;

            for (int gx = 0; gx < BlocksPerSide; gx++)
            for (int gz = 0; gz < BlocksPerSide; gz++)
            {
                if ((gx + gz) % 2 != 0) continue;   // every other intersection

                var position = new Vector3(
                    -half + RoadWidth * 0.5f + (gx + 1) * step - BlockSize * 0.5f - RoadWidth * 0.5f,
                    1.2f,
                    -half + RoadWidth * 0.5f + (gz + 1) * step - BlockSize * 0.5f - RoadWidth * 0.5f);

                var go = new GameObject("Spawn_" + gx + "_" + gz);
                go.transform.SetParent(transform, false);
                go.transform.position = position;
                go.transform.rotation = Quaternion.Euler(0f, _random.Next(4) * 90f, 0f);
                Spawns.Add(go.transform);
            }
        }

        /// <summary>Spawn points are spread across the whole map rather than split into
        /// two bases — this is a free-roam city, so teams start mixed into it.</summary>
        public Transform PickSpawn(Team team, int index)
        {
            if (Spawns.Count == 0) return transform;
            var offset = team == Team.Bravo ? Spawns.Count / 2 : 0;
            return Spawns[Mathf.Abs(index + offset) % Spawns.Count];
        }
    }
}
