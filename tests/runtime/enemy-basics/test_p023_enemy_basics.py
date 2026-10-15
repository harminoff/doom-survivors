import unittest

from tools.run_p023_enemy_basics import next_rng, parse_gameplay_event_trace, validate


HEADER = "\n".join(
    [
        "DS_P023_BOOT map=MAP09 ticrate=35 stage=FOREST enemy=BAT3 source_path=wiki:Mad_Forest#enemies[0] source_build=1.16.107 fixture=bat3-basic-v1 behavior=ENGINEERING_APPROXIMATION",
        "DS_P023_RULES movement_speed=0.500 contact_radii=(2.000,2.000) contact_distance=4.000 inclusive=1 health_milliunits=3000 player_health_milliunits=10000 contact_damage_milliunits=1250 attacker_cooldown_tics=7 player_invulnerability_tics=3 native_ai=0 native_solid=0 native_damage=0 native_pain=0 native_random=0 native_target=0 camera_frustum=SEPARATE",
        "DS_P023_AUTHORITY source_model=LOGICAL_XY_AND_TRANSACTIONS proxy=DSP023BasicEnemyProxy presentation_only=1 xp=REQUEST_ONLY drop=REQUEST_ONLY rng_stream=drop",
        "DS_P023_CONTACT_PHASE tic=1 mode=ONE_ATTACKER attackers=1 cadence=7",
        "DS_P023_CONTACT_PHASE tic=16 mode=MANY_ATTACKER attackers=2 order=stable_id global_invulnerability=1",
    ]
)


def contact(tic: int, stable_id: int, *, damage: int = 1250, accepted: int = 0,
            reason: str = "ATTACKER_COOLDOWN", health_before: int = 10000,
            health_after: int = 10000) -> str:
    return (
        f"DS_P023_CONTACT tic={tic} attacker_slot=0 generation=1 stable_id={stable_id} "
        f"target=PLAYER distance=0.000 radius_sum=4.000 inclusive=1 in_contact=1 "
        f"eligible=1 accepted={accepted} reason={reason} damage={damage} "
        f"player_health_before={health_before} player_health_after={health_after} "
        "cooldown_before=0 cooldown_after=0 invuln_before=0 invuln_after=0 camera_ignored=1"
    )


class P023ValidatorTests(unittest.TestCase):
    def test_named_drop_rng_transition_is_stable(self):
        self.assertEqual(next_rng(303), 77186717)

    def test_marker_only_log_fails_closed(self):
        result = validate(HEADER + "\nDS_P023_COMPLETE tics=70")
        self.assertEqual(result["status"], "FAIL")
        self.assertIn("actual movement trace is empty", result["errors"])
        self.assertIn("actual contact trace is empty", result["errors"])

    def test_wrong_cadence_is_rejected_from_individual_contacts(self):
        log = HEADER + "\n".join(
            [contact(1, 100, accepted=1, reason="SUCCESS", health_before=10000, health_after=8750),
             contact(8, 100, accepted=1, reason="SUCCESS", health_before=8750, health_after=7500),
             contact(14, 100, accepted=1, reason="SUCCESS", health_before=7500, health_after=6250)]
        )
        result = validate(log)
        self.assertTrue(any("isolated attacker cadence" in error for error in result["errors"]))

    def test_wrong_damage_and_stable_id_order_are_rejected(self):
        log = HEADER + "\n".join(
            [contact(1, 101, accepted=1, reason="SUCCESS", damage=999, health_before=10000, health_after=9001),
             contact(1, 100, accepted=0)]
        )
        result = validate(log)
        self.assertTrue(any("not ordered by tic and attacker stable ID" in error for error in result["errors"]))
        self.assertTrue(any("field damage is not independently derived" in error for error in result["errors"]))

    def test_despawn_reward_and_duplicate_death_drop_are_rejected(self):
        despawn = (
            "DS_P023_DESPAWN tic=30 target_slot=2 target_generation=1 target_id=102 released=1 "
            "life_before=LIVE life_after=RELEASED damage_delta=1 kill_delta=0 xp_delta=0 drop_delta=0 "
            "rng_stream=drop rng_before=303 rng_after=303 reward=NONE"
        )
        death = (
            "DS_P023_DEATH tic=20 target_slot=0 target_generation=1 target_id=100 health=0 "
            "kill_delta=1 kill_count=1 death_count=1 life_before=LIVE life_after=DEAD"
        )
        result = validate(HEADER + "\n" + despawn + "\n" + death + "\n" + death)
        self.assertTrue(any("despawn incorrectly awarded" in error for error in result["errors"]))
        self.assertTrue(any("death, XP request, and drop request" in error for error in result["errors"]))

    def test_stale_hit_cannot_target_replacement_generation(self):
        stale = (
            "DS_P023_STALE_HIT tic=32 slot=2 generation=1 stable_id=102 replacement_generation=1 "
            "replacement_id=102 accepted=0 reason=STALE_GENERATION"
        )
        result = validate(HEADER + "\n" + stale)
        self.assertTrue(any("stale generation hit" in error for error in result["errors"]))

    def test_camera_variant_required_for_each_front_side_rear_run(self):
        result = validate(HEADER + "\nDS_P023_CAMERA variant=1 yaw=90.000 pitch=0.000 fov=90.000 logical_xy=(0.000,0.000) camera_role=PRESENTATION_ONLY", expected_variant=2)
        self.assertTrue(any("expected camera variant 2" in error for error in result["errors"]))

    def test_camera_pose_mapping_rejects_tampered_yaw(self):
        result = validate(HEADER + "\nDS_P023_CAMERA variant=1 yaw=91.000 pitch=0.000 fov=90.000 logical_xy=(0.000,0.000) camera_role=PRESENTATION_ONLY", expected_variant=1)
        self.assertTrue(any("pose matrix" in error for error in result["errors"]))

    def test_full_gameplay_event_trace_preserves_order_and_fields(self):
        move = (
            "DS_P023_MOVE tic=1 slot=0 generation=1 stable_id=100 kind=BAT3 "
            "from=(1.000,0.000) to=(0.500,0.000) target=(0.000,0.000) "
            "distance_before=1.000 distance_after=0.500 step=0.500 speed=0.500 "
            "no_overshoot=1 camera_ignored=1"
        )
        trace = (
            "DS_P023_TRACE tic={tic} player_x=0.000 player_y=0.000 player_health=8750 "
            "player_invuln_until=4 kill_count=0 xp_requests=0 drop_requests=0 drop_rng=303 "
            "live=4 accepted_contacts=1 rejected_contacts=0 stale_rejected=0 camera_ignored=1"
        )
        first = parse_gameplay_event_trace(
            "\n".join([move, "DS_POSE tics=1 yaw=90.000", contact(1, 100, accepted=1, reason="SUCCESS", health_before=10000, health_after=8750), trace.format(tic=1), "DS_P023_FRAMEBUFFER_CAPTURE file=a.png"])
        )
        second = parse_gameplay_event_trace(
            "\n".join([move, contact(1, 100, accepted=1, reason="SUCCESS", health_before=10000, health_after=8750), trace.format(tic=2), "DS_P023_FRAMEBUFFER_CAPTURE file=b.png"])
        )
        self.assertEqual([event.split(":", 1)[0] for event in first], ["MOVE", "CONTACT", "TRACE"])
        self.assertIn('"tic":"1"', first[0])
        self.assertNotEqual(first, second)


if __name__ == "__main__":
    unittest.main()
