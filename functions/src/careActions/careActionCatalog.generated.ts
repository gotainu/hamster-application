// Generated from shared/care_action_catalog.json; do not edit.
// Canonical SHA-256: b520868e69494102be7e0c27ea7574311a8099f05a5a642903184311f586d81d
import type {CareActionCatalogItem} from './careActionCatalog';

export const CARE_ACTION_CATALOG_VERSION = "care_action_catalog_v2";
export const generatedCareActionCatalog: readonly CareActionCatalogItem[] = [
  {
    "id": "cageCleaning",
    "label": "ケージ掃除",
    "order": 10,
    "active": true,
    "inputType": "cleaning_choice",
    "legacyNames": [],
    "detail": {
      "key": "scope",
      "label": "掃除の範囲",
      "type": "enum",
      "unit": null,
      "meaning": "cleaning_scope",
      "values": [
        {
          "id": "full",
          "label": "全体"
        },
        {
          "id": "spot",
          "label": "一部"
        }
      ],
      "legacy": true
    },
    "details": [
      {
        "key": "cleaningType",
        "label": "掃除の内容",
        "type": "enum",
        "unit": null,
        "meaning": "cleaning_type",
        "values": [
          {
            "id": "spot_removal",
            "label": "汚れだけ"
          },
          {
            "id": "partial_cleaning",
            "label": "一部掃除"
          },
          {
            "id": "deep_cleaning",
            "label": "大掃除"
          }
        ]
      },
      {
        "key": "beddingReplacement",
        "label": "床材交換",
        "type": "enum",
        "unit": null,
        "meaning": "bedding_replacement",
        "onlyWhen": {
          "key": "cleaningType",
          "values": [
            "partial_cleaning",
            "deep_cleaning"
          ]
        },
        "values": [
          {
            "id": "none",
            "label": "なし"
          },
          {
            "id": "partial",
            "label": "一部"
          },
          {
            "id": "almost_all",
            "label": "ほぼ全部"
          }
        ]
      }
    ],
    "aliases": []
  },
  {
    "id": "roomWalk",
    "label": "お部屋散歩",
    "order": 20,
    "active": true,
    "inputType": "duration_minutes",
    "legacyNames": [],
    "detail": {
      "key": "durationMinutes",
      "label": "散歩時間（1日合計）",
      "type": "integer",
      "unit": "minutes",
      "meaning": "daily_total",
      "min": 1,
      "max": 1440,
      "values": []
    },
    "aliases": []
  }
];
