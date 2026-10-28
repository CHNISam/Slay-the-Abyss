"""Pin the locally audited fixed decompiled source; never fetch or execute it."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

COMMIT = "319009d5df0a82d9fb0f23cc22322286c6a87ec0"
FILES = ["relics/MoltenEgg2.java", "dungeons/AbstractDungeon.java", "rewards/RewardItem.java",
         "vfx/cardManip/ShowCardAndObtainEffect.java", "shop/ShopScreen.java",
         "vfx/campfire/CampfireSleepEffect.java", "events/beyond/SensoryStone.java"]


def evidence(archive):
    files, texts = {}, {}
    with zipfile.ZipFile(archive) as source:
        for name in FILES:
            member = f"sts-{COMMIT}/{name}"
            raw = source.read(member)
            files[name] = {"member": member, "sha256": hashlib.sha256(raw).hexdigest()}
            texts[name] = raw.decode()
    egg = texts[FILES[0]]
    for anchor in ['ID = "Molten Egg 2"', "RelicTier.UNCOMMON", "combatRewardScreen.rewards",
                   "c.type == AbstractCard.CardType.ATTACK && c.canUpgrade() && !c.upgraded",
                   "Settings.isEndless || AbstractDungeon.floorNum <= 48"]:
        assert anchor in egg, f"source changed: {anchor}"
    assert 'r.onObtainCard(this.card)' in texts[FILES[3]]
    assert 'r.onPreviewObtainCard(c)' in texts[FILES[4]]
    assert 'AbstractDungeon.cardRewardScreen.open' in texts[FILES[5]]
    assert 'new RewardItem(AbstractCard.CardColor.COLORLESS)' in texts[FILES[6]]
    return {"sourceCommit": COMMIT, "zipSha256": hashlib.sha256(Path(archive).read_bytes()).hexdigest(),
            "scope": "Molten Egg only; locally audited decompiled mirror, not authenticated PC binary or platform acceptance",
            "files": files,
            "contracts": {"id": "Molten Egg 2", "rarity": "uncommon", "type": "attack",
                          "requiresCanUpgrade": True, "requiresNotUpgraded": True, "upgradeCount": 1,
                          "previewCallsOnlyThisRelicObtain": True, "onEquipOwner": "combatRewardScreen.rewards.cards",
                          "onEquipDoesNotVisit": ["masterDeck", "shop", "directDreamCatcherList", "combatGeneration"],
                          "randomDraws": 0, "maxSpawnFloor": 48, "endlessBypass": True,
                          "ordinaryUpgradeRollPrecedesPreview": True,
                          "ordinarySuccessfulUpgradeSkipsPreview": True,
                          "colorlessPreviewOwner": "RewardItem(CardColor.COLORLESS)",
                          "shopPreview": ["initial-colored", "initial-colorless", "courier-colored", "courier-colorless"]}}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-zip", required=True)
    parser.add_argument("--output", default="tests/fixtures/molten-egg-source.json")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    result = evidence(args.source_zip)
    output = Path(args.output)
    if args.check:
        assert json.loads(output.read_text(encoding="utf-8")) == result, "Molten Egg source lock drift"
        print("MOLTEN_EGG_SOURCE_LOCK_PASS 7 exact members; no binary certification")
    else:
        output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
