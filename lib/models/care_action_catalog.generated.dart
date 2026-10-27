// Generated from shared/care_action_catalog.json; do not edit.
// Canonical SHA-256: b520868e69494102be7e0c27ea7574311a8099f05a5a642903184311f586d81d
part of 'care_action_catalog.dart';

const careActionCatalogVersion = "care_action_catalog_v2";
const careActionCatalog = <CareActionCatalogItem>[
  CareActionCatalogItem(
    id: "cageCleaning",
    label: "ケージ掃除",
    order: 10,
    active: true,
    inputType: "cleaning_choice",
    aliases: [],
    legacyNames: [],
    detail: CareActionDetail(
      key: "scope",
      label: "掃除の範囲",
      type: "enum",
      unit: null,
      meaning: "cleaning_scope",
      legacy: true,
      values: <CareActionDetailOption>[
        CareActionDetailOption(id: "full", label: "全体"),
        CareActionDetailOption(id: "spot", label: "一部"),
      ],
    ),
    details: <CareActionDetail>[
      CareActionDetail(
        key: "cleaningType",
        label: "掃除の内容",
        type: "enum",
        unit: null,
        meaning: "cleaning_type",
        values: <CareActionDetailOption>[
          CareActionDetailOption(id: "spot_removal", label: "汚れだけ"),
          CareActionDetailOption(id: "partial_cleaning", label: "一部掃除"),
          CareActionDetailOption(id: "deep_cleaning", label: "大掃除"),
        ],
      ),
      CareActionDetail(
        key: "beddingReplacement",
        label: "床材交換",
        type: "enum",
        unit: null,
        meaning: "bedding_replacement",
        onlyWhen: CareActionDetailCondition(key: "cleaningType", values: ["partial_cleaning", "deep_cleaning"]),
        values: <CareActionDetailOption>[
          CareActionDetailOption(id: "none", label: "なし"),
          CareActionDetailOption(id: "partial", label: "一部"),
          CareActionDetailOption(id: "almost_all", label: "ほぼ全部"),
        ],
      ),
    ],
  ),
  CareActionCatalogItem(
    id: "roomWalk",
    label: "お部屋散歩",
    order: 20,
    active: true,
    inputType: "duration_minutes",
    aliases: [],
    legacyNames: [],
    detail: CareActionDetail(
      key: "durationMinutes",
      label: "散歩時間（1日合計）",
      type: "integer",
      unit: "minutes",
      meaning: "daily_total",
      min: 1,
      max: 1440,
      values: <CareActionDetailOption>[
      ],
    ),
  ),
];
