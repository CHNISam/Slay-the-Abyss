import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
const hash=s=>createHash('sha256').update(s).digest('hex');
const binding={
  "beforeSha256": "ad7a52c5b5df717a9aa59c07bc70580d437017b95ff90a22455105b382807fd7",
  "afterSha256": "4025ab067e347788d61e16ecc67f52f3c3cd61012c7b9cc10f522db809767305",
  "hunks": [
    {
      "at": 984,
      "before": [
        "        -170,"
      ],
      "after": [
        "        -184,"
      ]
    },
    {
      "at": 986,
      "before": [
        "        170"
      ],
      "after": [
        "        184"
      ]
    },
    {
      "at": 989,
      "before": [
        "        56,",
        "        -32"
      ],
      "after": [
        "        46,",
        "        -46"
      ]
    },
    {
      "at": 993,
      "before": [
        "        148,",
        "        72"
      ],
      "after": [
        "        164,",
        "        80"
      ]
    },
    {
      "at": 998,
      "before": [
        "        -116,",
        "        576,",
        "        48"
      ],
      "after": [
        "        -118,",
        "        560,",
        "        44"
      ]
    },
    {
      "at": 1002,
      "before": [],
      "after": [
        "      \"header\": {",
        "        \"note\": \"标题与说明分行排布：标题 30 号居上，金色细线分隔，说明 16 号在线下，杜绝叠字。\",",
        "        \"titleY\": 176,",
        "        \"ruleY\": 146,",
        "        \"ruleSize\": [",
        "          120,",
        "          2",
        "        ],",
        "        \"hintY\": 120,",
        "        \"textHeight\": 36",
        "      },"
      ]
    }
  ]
};
export function prePotionManageSource(path,source){
 if(path!=='data/presentation/ui_theme.json'||typeof source!=='string')return source;
 const normalized=source.replaceAll('\r\n','\n');
 if(hash(normalized)!==binding.afterSha256)return source;
 const lines=normalized.split('\n');
 for(const h of [...binding.hunks].reverse()){
 assert.deepEqual(lines.slice(h.at,h.at+h.after.length),h.after);
 lines.splice(h.at,h.after.length,...h.before);
 }
 const previous=lines.join('\n');assert.equal(hash(previous),binding.beforeSha256);return previous;
}
