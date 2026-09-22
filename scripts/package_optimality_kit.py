"""Bundle the standalone, standard-library proof calculator and scoped examples."""
import hashlib
import json
import zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'dist/optimality-proof-kit-0.1.zip'


def main():
    payload={'optimality_bounds.py':(ROOT/'scripts/optimality_bounds.py').read_bytes()}
    evidence=ROOT/'research/optimality-evidence'
    for name in ('synthetic-worlds.json','synthetic-dominance.json'):
        payload['examples/'+name]=(evidence/name).read_bytes()
    for name in ('synthetic-certificates.json','existing-benchmark-audit.json','verification.json'):
        payload['reports/'+name]=(evidence/name).read_bytes()
    payload['README.md']='''# 条件最优证明工具 0.1

需要 Python 3.11 或更新版；只用标准库，无需 pip 安装。
解压后在此目录执行：

```
python optimality_bounds.py examples/synthetic-worlds.json
python optimality_bounds.py examples/synthetic-dominance.json
```

第一个例子没有共同最优，第二个例子有区间优势证书。
所有示例数字均为数学示例，不是 WoW 技能系数。证书仅针对所提供的收益表；
真实世界覆盖、收益界有效性和策略可执行性仍需另外验证。
本工具没有游戏客户端接口，也没有宣称或证明实战最高 DPS。
reports 内含已生成的例子和历史模拟摘要；重做历史原始数据审计需要完整源码
工作区中的 scripts/audit_optimality_evidence.py 及相应 dist 原始报告。
'''.encode('utf-8')
    manifest={name:hashlib.sha256(data).hexdigest() for name,data in payload.items()}
    payload['SHA256SUMS.json']=(json.dumps(manifest,indent=2)+'\n').encode()
    OUT.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(OUT,'w',compression=zipfile.ZIP_DEFLATED) as archive:
        for name,data in sorted(payload.items()):
            info=zipfile.ZipInfo('RotaAssist-ProofKit/'+name,date_time=(1980,1,1,0,0,0))
            info.compress_type=zipfile.ZIP_DEFLATED
            archive.writestr(info,data)
    with zipfile.ZipFile(OUT) as archive:
        for name,digest in manifest.items():
            if hashlib.sha256(archive.read('RotaAssist-ProofKit/'+name)).hexdigest()!=digest:
                raise ValueError('archive hash mismatch: '+name)
    print(json.dumps({'path':str(OUT),'bytes':OUT.stat().st_size,'files':len(payload),
                      'sha256':hashlib.sha256(OUT.read_bytes()).hexdigest()}))


if __name__=='__main__': main()
