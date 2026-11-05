// Verified project card data, develop 87c944f3d1ae89b01470cf89d6f7cc96cc4017ab; illustration icons remain placeholders.
export const projectCardReference = {
  "repository": "FurinyaWorks/Slay-the-Abyss",
  "branch": "develop",
  "commit": "87c944f3d1ae89b01470cf89d6f7cc96cc4017ab",
  "checkedAt": "2026-11-05T04:27:00Z",
  "note": "Display names/text from current traveler presentation; values/type/rarity from matching rules. This is existing project content, not new designs. Common pool has no power cards. Images are not established by this data.",
  "cards": [
    {
      "id": "cleave",
      "name": "星陨剑",
      "type": "attack",
      "rarity": "common",
      "cost": 1,
      "text": "对每个敌人造成 8 点伤害。",
      "upgradeCost": 1,
      "upgradeText": "对每个敌人造成 11 点伤害。",
      "target": "ALL_ENEMY",
      "effects": [
        {
          "op": "damageAll",
          "value": 8
        }
      ],
      "upgrade": {
        "effects": [
          {
            "op": "damageAll",
            "value": 11
          }
        ]
      },
      "exhaust": false,
      "source": {
        "rules": {
          "path": "data/cards.json",
          "startLine": 223,
          "endLine": 247,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/cards.json#L223-L247"
        },
        "presentation": {
          "path": "data/presentation/traveler.zh-CN.json",
          "startLine": 20,
          "endLine": 24,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/presentation/traveler.zh-CN.json#L20-L24"
        }
      }
    },
    {
      "id": "iron_wave",
      "name": "招架还击",
      "type": "attack",
      "rarity": "common",
      "cost": 1,
      "text": "先增加 5 点格挡，再对目标造成 5 点伤害。",
      "upgradeCost": 1,
      "upgradeText": "先增加 7 点格挡，再对目标造成 7 点伤害。",
      "target": "ENEMY",
      "effects": [
        {
          "op": "block",
          "value": 5
        },
        {
          "op": "damage",
          "value": 5
        }
      ],
      "upgrade": {
        "effects": [
          {
            "op": "block",
            "value": 7
          },
          {
            "op": "damage",
            "value": 7
          }
        ]
      },
      "exhaust": false,
      "source": {
        "rules": {
          "path": "data/cards.json",
          "startLine": 387,
          "endLine": 419,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/cards.json#L387-L419"
        },
        "presentation": {
          "path": "data/presentation/traveler.zh-CN.json",
          "startLine": 30,
          "endLine": 34,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/presentation/traveler.zh-CN.json#L30-L34"
        }
      }
    },
    {
      "id": "shrug_it_off",
      "name": "伺机而动",
      "type": "skill",
      "rarity": "common",
      "cost": 1,
      "text": "增加 8 点格挡，再抽 1 张牌。",
      "upgradeCost": 1,
      "upgradeText": "增加 11 点格挡，再抽 1 张牌。",
      "target": "SELF",
      "effects": [
        {
          "op": "block",
          "value": 8
        },
        {
          "op": "draw",
          "value": 1
        }
      ],
      "upgrade": {
        "effects": [
          {
            "op": "block",
            "value": 11
          },
          {
            "op": "draw",
            "value": 1
          }
        ]
      },
      "exhaust": false,
      "source": {
        "rules": {
          "path": "data/cards.json",
          "startLine": 485,
          "endLine": 517,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/cards.json#L485-L517"
        },
        "presentation": {
          "path": "data/presentation/traveler.zh-CN.json",
          "startLine": 70,
          "endLine": 74,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/presentation/traveler.zh-CN.json#L70-L74"
        }
      }
    },
    {
      "id": "armaments",
      "name": "整备武装",
      "type": "skill",
      "rarity": "common",
      "cost": 1,
      "text": "获得 5 点格挡，升级手中一张牌（本场战斗）。",
      "upgradeCost": 1,
      "upgradeText": "获得 5 点格挡，升级手中所有牌（本场战斗）。",
      "target": "SELF",
      "effects": [
        {
          "op": "block",
          "value": 5
        },
        {
          "op": "upgradeHand"
        }
      ],
      "upgrade": {
        "effects": [
          {
            "op": "block",
            "value": 5
          },
          {
            "op": "upgradeHand",
            "all": true
          }
        ]
      },
      "exhaust": false,
      "source": {
        "rules": {
          "path": "data/cards.json",
          "startLine": 143,
          "endLine": 174,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/cards.json#L143-L174"
        },
        "presentation": {
          "path": "data/presentation/traveler.zh-CN.json",
          "startLine": 202,
          "endLine": 206,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/presentation/traveler.zh-CN.json#L202-L206"
        }
      }
    },
    {
      "id": "uppercut",
      "name": "挑剑破势",
      "type": "attack",
      "rarity": "uncommon",
      "cost": 2,
      "text": "对目标造成 13 点伤害，再施加 1 回合虚弱和 1 回合易伤。",
      "upgradeCost": 2,
      "upgradeText": "对目标造成 13 点伤害，再施加 2 回合虚弱和 2 回合易伤。",
      "target": "ENEMY",
      "effects": [
        {
          "op": "damage",
          "value": 13
        },
        {
          "op": "applyStatus",
          "status": "weak",
          "value": 1
        },
        {
          "op": "applyStatus",
          "status": "vulnerable",
          "value": 1
        }
      ],
      "upgrade": {
        "effects": [
          {
            "op": "damage",
            "value": 13
          },
          {
            "op": "applyStatus",
            "status": "weak",
            "value": 2
          },
          {
            "op": "applyStatus",
            "status": "vulnerable",
            "value": 2
          }
        ]
      },
      "exhaust": false,
      "source": {
        "rules": {
          "path": "data/cards.json",
          "startLine": 1733,
          "endLine": 1777,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/cards.json#L1733-L1777"
        },
        "presentation": {
          "path": "data/presentation/traveler.zh-CN.json",
          "startLine": 85,
          "endLine": 89,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/presentation/traveler.zh-CN.json#L85-L89"
        }
      }
    },
    {
      "id": "shockwave",
      "name": "震慑敌阵",
      "type": "skill",
      "rarity": "uncommon",
      "cost": 2,
      "text": "为每个敌人施加 3 回合虚弱和 3 回合易伤。打出后消耗本牌。",
      "upgradeCost": 2,
      "upgradeText": "为每个敌人施加 5 回合虚弱和 5 回合易伤。打出后消耗本牌。",
      "target": "ALL_ENEMY",
      "effects": [
        {
          "op": "applyStatusAll",
          "status": "weak",
          "targetGroup": "weak_then_vulnerable",
          "value": 3
        },
        {
          "op": "applyStatusAll",
          "status": "vulnerable",
          "targetGroup": "weak_then_vulnerable",
          "value": 3
        }
      ],
      "upgrade": {
        "effects": [
          {
            "op": "applyStatusAll",
            "status": "weak",
            "targetGroup": "weak_then_vulnerable",
            "value": 5
          },
          {
            "op": "applyStatusAll",
            "status": "vulnerable",
            "targetGroup": "weak_then_vulnerable",
            "value": 5
          }
        ]
      },
      "exhaust": true,
      "source": {
        "rules": {
          "path": "data/cards.json",
          "startLine": 1664,
          "endLine": 1705,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/cards.json#L1664-L1705"
        },
        "presentation": {
          "path": "data/presentation/traveler.zh-CN.json",
          "startLine": 155,
          "endLine": 159,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/presentation/traveler.zh-CN.json#L155-L159"
        }
      }
    },
    {
      "id": "inflame",
      "name": "剑术精进",
      "type": "power",
      "rarity": "uncommon",
      "cost": 1,
      "text": "为自己增加 2 层力量。",
      "upgradeCost": 1,
      "upgradeText": "为自己增加 3 层力量。",
      "target": "SELF",
      "effects": [
        {
          "op": "gainStatus",
          "status": "strength",
          "value": 2
        }
      ],
      "upgrade": {
        "effects": [
          {
            "op": "gainStatus",
            "status": "strength",
            "value": 3
          }
        ]
      },
      "exhaust": false,
      "source": {
        "rules": {
          "path": "data/cards.json",
          "startLine": 1253,
          "endLine": 1279,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/cards.json#L1253-L1279"
        },
        "presentation": {
          "path": "data/presentation/traveler.zh-CN.json",
          "startLine": 90,
          "endLine": 94,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/presentation/traveler.zh-CN.json#L90-L94"
        }
      }
    },
    {
      "id": "metallicize",
      "name": "持续防守",
      "type": "power",
      "rarity": "uncommon",
      "cost": 1,
      "text": "每回合结束时获得 3 点格挡。",
      "upgradeCost": 1,
      "upgradeText": "每回合结束时获得 4 点格挡。",
      "target": "SELF",
      "effects": [
        {
          "op": "gainStatus",
          "value": 3,
          "status": "metallicize"
        }
      ],
      "upgrade": {
        "effects": [
          {
            "op": "gainStatus",
            "value": 4,
            "status": "metallicize"
          }
        ]
      },
      "exhaust": false,
      "source": {
        "rules": {
          "path": "data/cards.json",
          "startLine": 1310,
          "endLine": 1336,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/cards.json#L1310-L1336"
        },
        "presentation": {
          "path": "data/presentation/traveler.zh-CN.json",
          "startLine": 95,
          "endLine": 99,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/presentation/traveler.zh-CN.json#L95-L99"
        }
      }
    },
    {
      "id": "bludgeon",
      "name": "全力一击",
      "type": "attack",
      "rarity": "rare",
      "cost": 3,
      "text": "对目标造成 32 点伤害。",
      "upgradeCost": 3,
      "upgradeText": "对目标造成 42 点伤害。",
      "target": "ENEMY",
      "effects": [
        {
          "op": "damage",
          "value": 32
        }
      ],
      "upgrade": {
        "effects": [
          {
            "op": "damage",
            "value": 42
          }
        ]
      },
      "exhaust": false,
      "source": {
        "rules": {
          "path": "data/cards.json",
          "startLine": 1868,
          "endLine": 1892,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/cards.json#L1868-L1892"
        },
        "presentation": {
          "path": "data/presentation/traveler.zh-CN.json",
          "startLine": 180,
          "endLine": 184,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/presentation/traveler.zh-CN.json#L180-L184"
        }
      }
    },
    {
      "id": "impervious",
      "name": "坚守",
      "type": "skill",
      "rarity": "rare",
      "cost": 2,
      "text": "为自己增加 30 点格挡。打出后消耗本牌。",
      "upgradeCost": 2,
      "upgradeText": "为自己增加 40 点格挡。打出后消耗本牌。",
      "target": "SELF",
      "effects": [
        {
          "op": "block",
          "value": 30
        }
      ],
      "upgrade": {
        "effects": [
          {
            "op": "block",
            "value": 40
          }
        ]
      },
      "exhaust": true,
      "source": {
        "rules": {
          "path": "data/cards.json",
          "startLine": 2116,
          "endLine": 2141,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/cards.json#L2116-L2141"
        },
        "presentation": {
          "path": "data/presentation/traveler.zh-CN.json",
          "startLine": 170,
          "endLine": 174,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/presentation/traveler.zh-CN.json#L170-L174"
        }
      }
    },
    {
      "id": "barricade",
      "name": "永世的磐岩",
      "type": "power",
      "rarity": "rare",
      "cost": 3,
      "text": "自己的回合开始时，保留已有格挡。",
      "upgradeCost": 2,
      "upgradeText": "自己的回合开始时，保留已有格挡。",
      "target": "SELF",
      "effects": [
        {
          "op": "gainStatus",
          "status": "barricade",
          "value": 1
        }
      ],
      "upgrade": {
        "cost": 2
      },
      "exhaust": false,
      "source": {
        "rules": {
          "path": "data/cards.json",
          "startLine": 1808,
          "endLine": 1828,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/cards.json#L1808-L1828"
        },
        "presentation": {
          "path": "data/presentation/traveler.zh-CN.json",
          "startLine": 110,
          "endLine": 114,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/presentation/traveler.zh-CN.json#L110-L114"
        }
      }
    },
    {
      "id": "demon_form",
      "name": "渐入佳境",
      "type": "power",
      "rarity": "rare",
      "cost": 3,
      "text": "每回合开始时获得 2 层力量。",
      "upgradeCost": 3,
      "upgradeText": "每回合开始时获得 3 层力量。",
      "target": "NONE",
      "effects": [
        {
          "op": "gainStatus",
          "value": 2,
          "status": "demon_form"
        }
      ],
      "upgrade": {
        "effects": [
          {
            "op": "gainStatus",
            "value": 3,
            "status": "demon_form"
          }
        ]
      },
      "exhaust": false,
      "source": {
        "rules": {
          "path": "data/cards.json",
          "startLine": 1946,
          "endLine": 1972,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/cards.json#L1946-L1972"
        },
        "presentation": {
          "path": "data/presentation/traveler.zh-CN.json",
          "startLine": 175,
          "endLine": 179,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/presentation/traveler.zh-CN.json#L175-L179"
        }
      }
    }
  ],
  "starterCards": [
    {
      "id": "strike",
      "name": "普通攻击",
      "type": "attack",
      "rarity": "basic",
      "cost": 1,
      "text": "对目标造成 6 点伤害。",
      "upgradeCost": 1,
      "upgradeText": "对目标造成 9 点伤害。",
      "target": "ENEMY",
      "effects": [
        {
          "op": "damage",
          "value": 6
        }
      ],
      "upgrade": {
        "effects": [
          {
            "op": "damage",
            "value": 9
          }
        ]
      },
      "exhaust": false,
      "source": {
        "rules": {
          "path": "data/cards.json",
          "startLine": 20,
          "endLine": 45,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/cards.json#L20-L45"
        },
        "presentation": {
          "path": "data/presentation/traveler.zh-CN.json",
          "startLine": 5,
          "endLine": 9,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/presentation/traveler.zh-CN.json#L5-L9"
        }
      }
    },
    {
      "id": "defend",
      "name": "防御",
      "type": "skill",
      "rarity": "basic",
      "cost": 1,
      "text": "为自己增加 5 点格挡。",
      "upgradeCost": 1,
      "upgradeText": "为自己增加 8 点格挡。",
      "target": "SELF",
      "effects": [
        {
          "op": "block",
          "value": 5
        }
      ],
      "upgrade": {
        "effects": [
          {
            "op": "block",
            "value": 8
          }
        ]
      },
      "exhaust": false,
      "source": {
        "rules": {
          "path": "data/cards.json",
          "startLine": 47,
          "endLine": 71,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/cards.json#L47-L71"
        },
        "presentation": {
          "path": "data/presentation/traveler.zh-CN.json",
          "startLine": 10,
          "endLine": 14,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/presentation/traveler.zh-CN.json#L10-L14"
        }
      }
    },
    {
      "id": "bash",
      "name": "破防斩",
      "type": "attack",
      "rarity": "basic",
      "cost": 2,
      "text": "对目标造成 8 点伤害，再施加 2 回合易伤。",
      "upgradeCost": 2,
      "upgradeText": "对目标造成 10 点伤害，再施加 3 回合易伤。",
      "target": "ENEMY",
      "effects": [
        {
          "op": "damage",
          "value": 8
        },
        {
          "op": "applyStatus",
          "status": "vulnerable",
          "value": 2
        }
      ],
      "upgrade": {
        "effects": [
          {
            "op": "damage",
            "value": 10
          },
          {
            "op": "applyStatus",
            "status": "vulnerable",
            "value": 3
          }
        ]
      },
      "exhaust": false,
      "source": {
        "rules": {
          "path": "data/cards.json",
          "startLine": 73,
          "endLine": 107,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/cards.json#L73-L107"
        },
        "presentation": {
          "path": "data/presentation/traveler.zh-CN.json",
          "startLine": 15,
          "endLine": 19,
          "url": "https://github.com/FurinyaWorks/Slay-the-Abyss/blob/87c944f3d1ae89b01470cf89d6f7cc96cc4017ab/data/presentation/traveler.zh-CN.json#L15-L19"
        }
      }
    }
  ],
  "starterDeck": [
    "strike",
    "strike",
    "strike",
    "strike",
    "strike",
    "defend",
    "defend",
    "defend",
    "defend",
    "bash"
  ]
};
export const projectCards = projectCardReference.cards;
export const starterCards = projectCardReference.starterCards;
export const starterDeck = projectCardReference.starterDeck;
export const typeNames = {attack:"攻击",skill:"技能",power:"能力"};
export const rarityNames = {basic:"基础",common:"普通",uncommon:"罕见",rare:"稀有"};
