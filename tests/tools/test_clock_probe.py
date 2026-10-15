import unittest

from tools.run_clock_probe import EXPECTED_EVENTS, validate


def passing_log() -> str:
    lines = [
        "DS_BOOT map=MAP03",
        "DS_P014_BEGIN map=MAP03 ticrate=35 clock_model=CEIL_ABSOLUTE_DEADLINE world_tick_pause=true ui_tick_always=true input_hook=InputProcess render_hook=RenderOverlay intervals=100ms,250ms,1/3s",
        "DS_P014_SOURCE_FACT ticrate=35 worldtick=VALID_LEVEL_UNPAUSED uitick=ALWAYS input=InputProcess render=RenderOverlay",
        "DS_P014_MODAL_BEGIN kind=level_up engine_world_tick=72 simulation_tic=71",
        "DS_P014_MODAL_END kind=level_up engine_world_tick=82 simulation_tic=71 backlog=0",
        "DS_P014_MODAL_BEGIN kind=chest engine_world_tick=100 simulation_tic=89",
        "DS_P014_MODAL_END kind=chest engine_world_tick=110 simulation_tic=89 backlog=0",
        "DS_P014_UI_OBSERVATION ui_ticks=35 world_ticks=UI_CONTEXT_SEPARATE simulation_tic=UI_CONTEXT_SEPARATE",
        "DS_P014_RENDER_OBSERVATION render_frames=30 world_ticks=UI_CONTEXT_SEPARATE simulation_tic=UI_CONTEXT_SEPARATE",
        "DS_P014_INPUT_OBSERVATION input_events=1",
        "DS_P014_UI_WINDOW_COMPLETE ui_ticks=350",
    ]
    lines.extend(
        f"DS_P014_EVENT clock={clock} priority={priority} event_index={index} simulation_tic={simulation_tic} engine_world_tick={engine_tick}"
        for clock, priority, index, simulation_tic, engine_tick in EXPECTED_EVENTS
    )
    lines.append(
        "DS_P014_COMPLETE engine_world_ticks=350 simulation_tics=330 events_100ms=94 events_250ms=37 events_third=28 modal_backlog=0 render_frames=UI_CONTEXT_SEPARATE input_observations=UI_CONTEXT_SEPARATE input_physics_limit=35HZ_BOUNDARY raw_input_observation=SEPARATE render_fps_observed=NOT_MEASURED"
    )
    lines.append("DS_P014_RENDER_MEASURED frames=3500 elapsed_ms=10000.0")
    lines.append("DS_P014_NATIVE_PAUSE_BEGIN ui_ticks=150 engine_world_tick=150 simulation_tic=130")
    lines.append("DS_P014_NATIVE_PAUSE_HELD ui_ticks=151 engine_world_tick=150 simulation_tic=130")
    lines.append("DS_P014_NATIVE_RESUME ui_ticks=221 engine_world_tick=150 simulation_tic=130 paused_engine_ticks=0 paused_sim_ticks=0")
    return "\n".join(lines)


class ClockProbeParserTests(unittest.TestCase):
    def test_expected_trace_passes(self):
        result = validate(passing_log())
        self.assertEqual(result["status"], "PASS", result["errors"])
        self.assertEqual(result["expected_event_count"], 159)

    def test_reordered_simultaneous_event_fails(self):
        lines = passing_log().splitlines()
        first = next(index for index, line in enumerate(lines) if "clock=100ms" in line)
        second = next(index for index, line in enumerate(lines) if "clock=third" in line)
        lines[first], lines[second] = lines[second], lines[first]
        self.assertEqual(validate("\n".join(lines))["status"], "FAIL")

    def test_modal_backlog_or_hidden_simulation_fails(self):
        log = passing_log().replace("simulation_tic=71 backlog=0", "simulation_tic=72 backlog=1", 1)
        self.assertEqual(validate(log)["status"], "FAIL")

    def test_missing_source_or_completion_marker_fails(self):
        log = passing_log().replace("DS_P014_SOURCE_FACT", "DS_P014_SOURCE_FACT_MISSING")
        self.assertEqual(validate(log)["status"], "FAIL")
        self.assertEqual(validate(log.replace("DS_P014_COMPLETE", "DS_P014_COMPLETE_MISSING"))["status"], "FAIL")

    def test_measured_rate_is_reported_separately_from_the_cap(self):
        result = validate(passing_log())
        self.assertEqual(result["measured_render"]["frames"], 3500)
        self.assertEqual(result["measured_render"]["measured_fps"], 350.0)

    def test_missing_measured_observation_fails(self):
        log = passing_log().replace("DS_P014_RENDER_MEASURED", "DS_P014_RENDER_MEASURED_MISSING")
        self.assertEqual(validate(log)["status"], "FAIL")

    def test_vm_abort_fails_even_after_completion_marker(self):
        # A truncated run whose completion marker already printed must not pass.
        log = passing_log().replace(
            "DS_P014_RENDER_MEASURED",
            "VM execution aborted: string format failed.\nDS_P014_RENDER_MEASURED",
            1,
        )
        result = validate(log)
        self.assertEqual(result["status"], "FAIL")
        self.assertTrue(any("vm failure" in error for error in result["errors"]))

    def test_missing_ui_window_completion_fails(self):
        log = passing_log().replace("DS_P014_UI_WINDOW_COMPLETE", "DS_P014_UI_WINDOW_INCOMPLETE")
        self.assertEqual(validate(log)["status"], "FAIL")

    def test_native_pause_freezes_logical_time(self):
        result = validate(passing_log())
        self.assertEqual(result["native_pause"]["paused_engine_ticks"], 0)
        self.assertEqual(result["native_pause"]["paused_sim_ticks"], 0)
        self.assertGreater(result["native_pause"]["resume_ui_ticks"], result["native_pause"]["begin_ui_ticks"])

    def test_hidden_advancement_during_pause_fails(self):
        log = passing_log().replace("paused_engine_ticks=0 paused_sim_ticks=0", "paused_engine_ticks=70 paused_sim_ticks=70")
        self.assertEqual(validate(log)["status"], "FAIL")

    def test_missing_native_pause_cycle_fails(self):
        log = passing_log().replace("DS_P014_NATIVE_RESUME", "DS_P014_NATIVE_RESUME_MISSING")
        self.assertEqual(validate(log)["status"], "FAIL")


if __name__ == "__main__":
    unittest.main()
