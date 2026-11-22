import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import oficina_ctm


class OficinaMapTests(unittest.TestCase):
    def test_new_map_has_walkable_route(self):
        self.assertEqual(oficina_ctm.validate_map(oficina_ctm.blank_map()), [])

    def test_scene_import_keeps_spawns_and_mechanisms(self):
        root = Path(__file__).resolve().parents[1]
        data = oficina_ctm.import_godot_scene(root / "levels/authored/floor_001_workshop.tscn")
        self.assertEqual(data["floor"], 1)
        self.assertEqual(data["start"], [1, 2])
        self.assertGreater(len(data["entity_spawns"]), 5)
        self.assertEqual({m["kind"] for m in data["mechanisms"]}, {"crate", "pressure_plate", "gate"})
        self.assertFalse(data["authoritative_spawns"], "scene import preserves the blueprint's current default spawn behavior")
        self.assertEqual(oficina_ctm.validate_map(data), [])

    def test_route_block_is_reported(self):
        data = oficina_ctm.blank_map(2, 9, 9)
        data["start"], data["portal"] = [1, 1], [7, 7]
        data["walls"] = [[4, y] for y in range(1, 8)]
        self.assertTrue(any("bloqueiam o caminho" in issue for issue in oficina_ctm.validate_map(data)))

    def test_wrong_circuit_channel_is_reported(self):
        data = oficina_ctm.blank_map()
        data["mechanisms"] = [
            {"kind": "power_source", "id": "source", "cell": [2, 2], "outputs": ["gate"]},
            {"kind": "gate", "id": "gate", "cell": [3, 2], "outputs": []},
        ]
        self.assertTrue(any("Ligação incompatível" in issue for issue in oficina_ctm.validate_map(data)))

    def test_save_format_roundtrip(self):
        data = oficina_ctm.blank_map(8, 17, 13)
        data["entity_spawns"].append({"kind": "pickup", "subtype": "shield", "cell": [3, 2]})
        restored = __import__("json").loads(__import__("json").dumps(data))
        self.assertEqual(oficina_ctm.validate_map(restored), [])
        self.assertEqual(restored["entity_spawns"][0]["subtype"], "shield")


if __name__ == "__main__":
    unittest.main()
