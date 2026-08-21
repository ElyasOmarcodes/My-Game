using System.Collections.Generic;
using UnityEngine;

namespace BattleOfAgents.Gameplay.World
{
    /// <summary>Accumulates axis-aligned (optionally yawed) boxes into one mesh.
    ///
    /// Everything visible in this game — every building, every agent, every weapon —
    /// is boxes. Merging them per material means a whole city block or a whole
    /// character costs a single draw call instead of dozens, which is the difference
    /// between 60 fps and 25 on a mid-range phone. It also means the APK ships no
    /// mesh assets at all.</summary>
    public class BoxMeshBuilder
    {
        readonly List<Vector3> _vertices = new List<Vector3>();
        readonly List<Vector3> _normals = new List<Vector3>();
        readonly List<Vector2> _uvs = new List<Vector2>();
        readonly List<int> _triangles = new List<int>();

        public int BoxCount { get; private set; }
        public bool IsEmpty { get { return _vertices.Count == 0; } }

        static readonly Vector3[] FaceNormals =
        {
            Vector3.forward, Vector3.back, Vector3.left,
            Vector3.right, Vector3.up, Vector3.down
        };

        // corner offsets per face, in unit-cube space (-0.5 .. 0.5)
        static readonly Vector3[][] FaceCorners =
        {
            new[] { new Vector3(-.5f,-.5f, .5f), new Vector3( .5f,-.5f, .5f), new Vector3( .5f, .5f, .5f), new Vector3(-.5f, .5f, .5f) }, // +Z
            new[] { new Vector3( .5f,-.5f,-.5f), new Vector3(-.5f,-.5f,-.5f), new Vector3(-.5f, .5f,-.5f), new Vector3( .5f, .5f,-.5f) }, // -Z
            new[] { new Vector3(-.5f,-.5f,-.5f), new Vector3(-.5f,-.5f, .5f), new Vector3(-.5f, .5f, .5f), new Vector3(-.5f, .5f,-.5f) }, // -X
            new[] { new Vector3( .5f,-.5f, .5f), new Vector3( .5f,-.5f,-.5f), new Vector3( .5f, .5f,-.5f), new Vector3( .5f, .5f, .5f) }, // +X
            new[] { new Vector3(-.5f, .5f, .5f), new Vector3( .5f, .5f, .5f), new Vector3( .5f, .5f,-.5f), new Vector3(-.5f, .5f,-.5f) }, // +Y
            new[] { new Vector3(-.5f,-.5f,-.5f), new Vector3( .5f,-.5f,-.5f), new Vector3( .5f,-.5f, .5f), new Vector3(-.5f,-.5f, .5f) }, // -Y
        };

        public void Add(Vector3 center, Vector3 size, float yawDegrees = 0f)
        {
            var rotation = Mathf.Abs(yawDegrees) > 0.01f
                ? Quaternion.Euler(0f, yawDegrees, 0f)
                : Quaternion.identity;

            for (int face = 0; face < 6; face++)
            {
                var normal = rotation * FaceNormals[face];
                var first = _vertices.Count;
                var corners = FaceCorners[face];

                // UVs tile with world size so a 40 m wall does not look like a 2 m one.
                var uvScale = UvScaleFor(face, size);

                for (int i = 0; i < 4; i++)
                {
                    var local = Vector3.Scale(corners[i], size);
                    _vertices.Add(center + rotation * local);
                    _normals.Add(normal);
                    _uvs.Add(new Vector2(
                        (corners[i].x + 0.5f) * uvScale.x,
                        (corners[i].y + 0.5f) * uvScale.y));
                }

                _triangles.Add(first);
                _triangles.Add(first + 2);
                _triangles.Add(first + 1);
                _triangles.Add(first);
                _triangles.Add(first + 3);
                _triangles.Add(first + 2);
            }
            BoxCount++;
        }

        static Vector2 UvScaleFor(int face, Vector3 size)
        {
            switch (face)
            {
                case 0: case 1: return new Vector2(size.x, size.y);
                case 2: case 3: return new Vector2(size.z, size.y);
                default:        return new Vector2(size.x, size.z);
            }
        }

        public Mesh Build(string name)
        {
            var mesh = new Mesh { name = name };
            // A city block can exceed 65k vertices, so use 32-bit indices.
            mesh.indexFormat = _vertices.Count > 65000
                ? UnityEngine.Rendering.IndexFormat.UInt32
                : UnityEngine.Rendering.IndexFormat.UInt16;

            mesh.SetVertices(_vertices);
            mesh.SetNormals(_normals);
            mesh.SetUVs(0, _uvs);
            mesh.SetTriangles(_triangles, 0);
            mesh.RecalculateBounds();
            mesh.UploadMeshData(true);   // frees the CPU copy: less RAM on device
            return mesh;
        }

        /// <summary>Builds the mesh, attaches it to a new child object and returns it.</summary>
        public GameObject Emit(Transform parent, string name, Material material,
            bool addCollider = false, bool markStatic = true)
        {
            if (IsEmpty) return null;

            var go = new GameObject(name, typeof(MeshFilter), typeof(MeshRenderer));
            go.transform.SetParent(parent, false);
            go.GetComponent<MeshFilter>().sharedMesh = BuildForCollider(name, addCollider, go);
            var renderer = go.GetComponent<MeshRenderer>();
            renderer.sharedMaterial = material;
            renderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.On;
            go.isStatic = markStatic;
            return go;
        }

        Mesh BuildForCollider(string name, bool addCollider, GameObject go)
        {
            // A collider needs the readable copy, so only free it when nothing reads back.
            var mesh = new Mesh { name = name };
            mesh.indexFormat = _vertices.Count > 65000
                ? UnityEngine.Rendering.IndexFormat.UInt32
                : UnityEngine.Rendering.IndexFormat.UInt16;
            mesh.SetVertices(_vertices);
            mesh.SetNormals(_normals);
            mesh.SetUVs(0, _uvs);
            mesh.SetTriangles(_triangles, 0);
            mesh.RecalculateBounds();

            if (addCollider)
            {
                var collider = go.AddComponent<MeshCollider>();
                collider.sharedMesh = mesh;
            }
            else
            {
                mesh.UploadMeshData(true);
            }
            return mesh;
        }
    }
}
