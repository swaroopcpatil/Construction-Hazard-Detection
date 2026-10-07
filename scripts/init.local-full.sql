INSERT INTO sites (id, name)
VALUES (1, 'Local Demo')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

SELECT setval(
    pg_get_serial_sequence('sites', 'id'),
    GREATEST((SELECT MAX(id) FROM sites), 1)
);

INSERT INTO site_groups (site_id, group_id)
VALUES (1, 1)
ON CONFLICT DO NOTHING;

INSERT INTO detection_model_catalog (
    model_key,
    definition,
    display_order,
    is_default
)
VALUES (
    'yolo26n',
    $$
    {
      "display_name": "Local YOLO26 Nano",
      "version": "local-demo",
      "artifact": "models/pt/best_yolo26n.pt",
      "sha256": "80c463daf7cf151f20e92231276162607bc4611c013cfb6e052b89442b764b1d",
      "enabled": true,
      "capabilities": ["image", "stream"],
      "tenant_ids": [],
      "site_ids": [],
      "roles": ["admin", "user", "guest", "super_admin"],
      "classes": [
        {"id": 0, "code": "hardhat", "display_name": "Hardhat"},
        {"id": 1, "code": "mask", "display_name": "Mask"},
        {"id": 2, "code": "no-hardhat", "display_name": "NO-Hardhat"},
        {"id": 3, "code": "no-mask", "display_name": "NO-Mask"},
        {"id": 4, "code": "no-safety-vest", "display_name": "NO-Safety Vest"},
        {"id": 5, "code": "person", "display_name": "Person"},
        {"id": 6, "code": "safety-cone", "display_name": "Safety Cone"},
        {"id": 7, "code": "safety-vest", "display_name": "Safety Vest"},
        {"id": 8, "code": "machinery", "display_name": "Machinery"},
        {"id": 9, "code": "utility-pole", "display_name": "Utility Pole"},
        {"id": 10, "code": "vehicle", "display_name": "Vehicle"}
      ]
    }
    $$::json,
    1,
    true
)
ON CONFLICT (model_key) DO UPDATE SET
    definition = EXCLUDED.definition,
    display_order = EXCLUDED.display_order,
    is_default = EXCLUDED.is_default;

INSERT INTO stream_configs (
    group_id,
    site_id,
    stream_name,
    video_url,
    model_key,
    detect_no_safety_vest_or_helmet,
    detect_near_machinery_or_vehicle,
    detect_in_restricted_area,
    detect_in_utility_pole_restricted_area,
    detect_machinery_close_to_pole,
    recognition_enabled,
    expire_date
)
VALUES (
    1,
    1,
    'quickstart-camera',
    'rtsp://media-server:8554/test-video',
    'yolo26n',
    true,
    true,
    true,
    false,
    false,
    true,
    NULL
)
ON CONFLICT (site_id, stream_name) DO UPDATE SET
    video_url = EXCLUDED.video_url,
    model_key = EXCLUDED.model_key,
    detect_no_safety_vest_or_helmet = EXCLUDED.detect_no_safety_vest_or_helmet,
    detect_near_machinery_or_vehicle = EXCLUDED.detect_near_machinery_or_vehicle,
    detect_in_restricted_area = EXCLUDED.detect_in_restricted_area,
    detect_in_utility_pole_restricted_area = EXCLUDED.detect_in_utility_pole_restricted_area,
    detect_machinery_close_to_pole = EXCLUDED.detect_machinery_close_to_pole,
    recognition_enabled = EXCLUDED.recognition_enabled,
    expire_date = EXCLUDED.expire_date;

INSERT INTO user_sites (user_id, site_id)
VALUES (
    (SELECT id FROM users WHERE username = 'user'),
    1
)
ON CONFLICT (user_id, site_id) DO NOTHING;

INSERT INTO user_identities (user_id, provider, provider_user_id, display_name)
VALUES (
    (SELECT id FROM users WHERE username = 'user'),
    'keycloak',
    'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    'Local Demo User'
)
ON CONFLICT (provider, provider_user_id) DO UPDATE SET
    user_id = EXCLUDED.user_id,
    display_name = EXCLUDED.display_name;
