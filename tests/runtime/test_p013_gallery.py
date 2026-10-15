from tools.run_asset_gallery import validate


GOOD_LOG = """
DS_P013_GALLERY_BEGIN map=MAP02 manifest_assets=7 fixture_instances=11 cases=8 ring_radius=96.000 target=(-208.000,0.000) collision_overlay=true classification=GENERATED_PLACEHOLDER
DS_P013_GALLERY_SPAWN count=11 expected=11 ownership=ADAPTER_WORLD_LOADED map_things=false
DS_P013_COLLISION_OVERLAY presentation_solid=false presentation_blocking=false presentation_interaction=false source_dimensions=UNKNOWN source_geometry_claim=NONE
DS_P013_ASSET actor=enemy_directional pos=(-208.000,0.000,0.000) policy=EIGHT_DIRECTIONAL_SPRITE collision=ENGINEERING_ENEMY_BODY_PLACEHOLDER presentation_solid=false presentation_blocking=false presentation_interaction=false
DS_P013_ASSET actor=enemy_directional pos=(96.000,0.000,0.000) policy=EIGHT_DIRECTIONAL_SPRITE collision=ENGINEERING_ENEMY_BODY_PLACEHOLDER presentation_solid=false presentation_blocking=false presentation_interaction=false
DS_P013_ASSET actor=player_identity pos=(-224.000,-96.000,0.000) policy=FRONT_BILLBOARD_PLACEHOLDER collision=ENGINEERING_PLAYER_BODY_PLACEHOLDER presentation_solid=false presentation_blocking=false presentation_interaction=false
DS_P013_ASSET actor=projectile pos=(-152.000,-48.000,48.000) policy=BILLBOARD_PLACEHOLDER collision=ENGINEERING_PROJECTILE_PLACEHOLDER presentation_solid=false presentation_blocking=false presentation_interaction=false
DS_P013_ASSET actor=projectile pos=(-152.000,48.000,56.000) policy=BILLBOARD_PLACEHOLDER collision=ENGINEERING_PROJECTILE_PLACEHOLDER presentation_solid=false presentation_blocking=false presentation_interaction=false
DS_P013_ASSET actor=projectile pos=(-96.000,0.000,72.000) policy=BILLBOARD_PLACEHOLDER collision=ENGINEERING_PROJECTILE_PLACEHOLDER presentation_solid=false presentation_blocking=false presentation_interaction=false
DS_P013_ASSET actor=ground_aura pos=(-88.000,64.000,0.000) policy=GROUND_ALIGNED_EFFECT collision=ENGINEERING_AREA_EFFECT_PLACEHOLDER presentation_solid=false presentation_blocking=false presentation_interaction=false
DS_P013_ASSET actor=ground_aura pos=(-88.000,-64.000,0.000) policy=GROUND_ALIGNED_EFFECT collision=ENGINEERING_AREA_EFFECT_PLACEHOLDER presentation_solid=false presentation_blocking=false presentation_interaction=false
DS_P013_ASSET actor=ground_aura pos=(-40.000,64.000,0.000) policy=GROUND_ALIGNED_EFFECT collision=ENGINEERING_AREA_EFFECT_PLACEHOLDER presentation_solid=false presentation_blocking=false presentation_interaction=false
DS_P013_ASSET actor=foot_pickup pos=(-120.000,32.000,0.000) policy=BILLBOARD_PLACEHOLDER collision=ENGINEERING_PICKUP_PLACEHOLDER presentation_solid=false presentation_blocking=false presentation_interaction=false
DS_P013_ASSET actor=world_prop pos=(-16.000,-96.000,0.000) policy=BILLBOARD_PLACEHOLDER collision=ENGINEERING_WORLD_PROP_PLACEHOLDER presentation_solid=false presentation_blocking=false presentation_interaction=false
DS_P013_GALLERY_CASE case=0 yaw=0 pitch=0 fov=90 body=(-304,0,0) target=(-208,0) ring_radius=96
DS_P013_GALLERY_CASE case=1 yaw=45 pitch=0 fov=90 body=(-276,-68,0) target=(-208,0) ring_radius=96
DS_P013_GALLERY_CASE case=2 yaw=90 pitch=0 fov=90 body=(-208,-96,0) target=(-208,0) ring_radius=96
DS_P013_GALLERY_CASE case=3 yaw=135 pitch=0 fov=90 body=(-140,-68,0) target=(-208,0) ring_radius=96
DS_P013_GALLERY_CASE case=4 yaw=180 pitch=0 fov=90 body=(-112,0,0) target=(-208,0) ring_radius=96
DS_P013_GALLERY_CASE case=5 yaw=225 pitch=0 fov=90 body=(-140,68,0) target=(-208,0) ring_radius=96
DS_P013_GALLERY_CASE case=6 yaw=270 pitch=0 fov=90 body=(-208,96,0) target=(-208,0) ring_radius=96
DS_P013_GALLERY_CASE case=7 yaw=315 pitch=0 fov=90 body=(-276,68,0) target=(-208,0) ring_radius=96
DS_P013_GALLERY_COMPLETE cases=8 fixture_instances=11 collision_overlay=true ring_stable=true body_restored=true
DS_RUNTIME_COMPLETE tics=65 pos=(-320,0,0) yaw=0 pitch=0
"""


def test_gallery_validator_accepts_complete_generated_run():
    assert validate(GOOD_LOG)["status"] == "PASS"


def test_gallery_validator_rejects_missing_overlay_or_case():
    missing_overlay = GOOD_LOG.replace(
        "DS_P013_COLLISION_OVERLAY presentation_solid=false presentation_blocking=false presentation_interaction=false source_dimensions=UNKNOWN source_geometry_claim=NONE\n",
        "",
        1,
    )
    assert validate(missing_overlay)["status"] == "FAIL"
    assert validate(GOOD_LOG.replace("DS_P013_GALLERY_CASE case=7", "DS_P013_GALLERY_CASE case=9", 1))["status"] == "FAIL"
    assert validate(GOOD_LOG.replace("body=(-276,68,0)", "body=(-304,0,0)", 1))["status"] == "FAIL"
    assert validate(GOOD_LOG.replace("actor=projectile pos=(-96.000,0.000,72.000)", "actor=ui_icon pos=(-96.000,0.000,72.000)", 1))["status"] == "FAIL"
