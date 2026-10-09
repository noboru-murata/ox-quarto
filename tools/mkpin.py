# mkpin.py — _quarto/yaml/talk-*.yaml (見出しが動く版) から talk-*-pin.yaml (見出し固定版) を作る．
# 使い方: python3 tools/mkpin.py <リポジトリのフォルダ>   (make -C samples pin-yaml)
# 固定版は theme の line-deck (talk-logo は logo-deck) の後に pin-deck.scss を足しただけ．
# 大元の org に #+QUARTO_VARIANT: pin と書くと読まれる (lisp/ox-quarto-ext/ox-quarto-ext-variant.el)．
# 元の yaml に pin-deck の行があれば消す (元の yaml は常に動く版)．
import glob, os, re, sys
os.chdir(sys.argv[1])
PIN = "      - _quarto/scss/pin-deck.scss           # 修飾: 見出しを上に固定し，本文だけを中央に\n"
for p in sorted(glob.glob('_quarto/yaml/talk-*.yaml')):
    if os.path.islink(p) or p.endswith('-pin.yaml'): continue
    name = os.path.basename(p)[:-5]
    ls = open(p).read().splitlines(keepends=True)
    ls = [l for l in ls if 'pin-deck.scss' not in l]          # base: 動く版のまま
    open(p, 'w').write(''.join(ls))
    anchor = 'logo-deck.scss' if name == 'talk-logo' else 'line-deck.scss'
    idx = [i for i, l in enumerate(ls) if anchor in l and l.lstrip().startswith('- ')]
    assert len(idx) == 1, p
    out = ls[:idx[0]+1] + [PIN] + ls[idx[0]+1:]
    assert out[0].startswith('# ' + name + ' '), out[0]
    out[0] = out[0].replace('# ' + name + ' ', '# ' + name + '-pin ', 1)
    out.insert(1, f"# {name}.yaml の見出し固定版: 違いは theme の pin-deck.scss の 1 行だけ．\n"
                  f"# 大元の org に  #+QUARTO_VARIANT: pin  と書くと {name}.yaml の代わりに読まれる (lisp/ox-quarto-ext-variant.el)．\n"
                  f"# {name}.yaml を直したら make -C samples pin-yaml (tools/mkpin.py) で作り直す．\n")
    open(f'_quarto/yaml/{name}-pin.yaml', 'w').write(''.join(out))
    print('wrote', f'{name}-pin.yaml')
