#!/usr/bin/env python3
# oxq-tex-macros.py — 自作の LaTeX マクロを展開し, MathJax が解釈できる素の TeX にする
#
# 入力は org / tex / qmd / md のどれでもよい (テキストとして処理する). 行頭が # または % の行 (コメント) は
# 触らない (#+ で始まる org のキーワード行は処理の対象).
#
# 使い方:
#   oxq-tex-macros.py INPUT -m macros.json [-o OUTPUT] [--from-line N]   # マクロを展開して書き出す
#   oxq-tex-macros.py INPUT -m macros.json --report                        # 展開後に MathJax で動かない/要確認の命令を一覧する
#   oxq-tex-macros.py --init preamble.tex > macros.json                    # プリアンブルから定義の雛形を作る
#
#   --from-line N : N 行目より前 (プリアンブルなど) は触らない
#   展開できなかったものや旧形式の使い方は標準エラー出力に [warn] で出る.
#
# マクロの定義ファイル (JSON): {"macros": [ {"name": "abs", "kind": "paired", ...}, ... ]}
# 例は oxq-tex-macros.example.json (統計の本で使った 20 個ほど). kind は次の 7 種類.
#
#  sym     引数なし. 置き換えるだけ.                {"name":"trans","kind":"sym","tex":"{\\mathsf{T}}"}
#  cmd     \newcommand 相当. 引数 #1..#9.           {"name":"R","kind":"cmd","args":1,"body":"\\mathbb{R}^{#1}"}
#          "opt":"既定値" を付けると先頭の引数が [..] の省略可能な引数になる.
#  paired  mathtools の \DeclarePairedDelimiter(X) 相当. \name*{..} は \left\right, \name[\big]{..} は \bigl\bigr,
#          指定なしは素の括弧.                      {"name":"abs","kind":"paired","l":"\\lvert","r":"\\rvert"}
#          "args":n, "body":"#1,#2" で複数引数. "prefix"/"suffix" で前後に付ける (#n 使用可).
#          "given":true で本文中の \given を \mid (星印・大きさ指定に合わせて \middle| など) にする.
#          body 中の "#|" は区切り線で, "bar" (既定 \vert) を大きさに合わせて出す. "empty" は引数が空のときの代用.
#  stat    \Ex{主}[添字](上付き) 型 (E, Var, Cov など).  {"name":"Ex","kind":"stat","head":"\\mathbb{E}","l":"[","r":"]"}
#          旧形式 \Ex{添字}{上付き}{主} も添字版に直して警告する.
#  optsub  \Dat[n] -> \mathcal{D}_{n} 型.             {"name":"Dat","kind":"optsub","base":"\\mathcal{D}"}
#  bigo    \Ord[添字](x) -> \mathscr{O}_{\mathrm{添字}}\left(x\right) 型.  {"name":"Ord","kind":"bigo","sym":"\\mathscr{O}"}
import re, sys, json, argparse, bisect

SIZES = r'\big \Big \bigg \Bigg'.split()


class Fail(Exception):
    pass


def match(s, i, o, c):
    """s[i]==o の対応する閉じ括弧の直後の位置を返す."""
    d = 0
    in_comment = False
    for j in range(i, len(s)):
        if in_comment:
            if s[j] == '\n':
                in_comment = False
            continue
        if s[j] == '%' and (j == 0 or s[j - 1] != '\\'):
            in_comment = True
            continue
        if s[j] == o and (j == 0 or s[j - 1] != '\\'):
            d += 1
        elif s[j] == c and (j == 0 or s[j - 1] != '\\'):
            d -= 1
            if d == 0:
                return j + 1
    raise Fail(f'unbalanced {o}{c}')


def take_star_opt(s, i):
    star = False
    size = None
    if i < len(s) and s[i] == '*':
        star = True
        i += 1
    if i < len(s) and s[i] == '[':
        j = match(s, i, '[', ']')
        size = s[i + 1:j - 1].strip()
        i = j
    return star, size, i


def take_brace(s, i):
    while i < len(s) and s[i] in ' \t':
        i += 1
    if i >= len(s) or s[i] != '{':
        raise Fail('brace expected')
    j = match(s, i, '{', '}')
    return s[i + 1:j - 1], j


def sp(d):
    r"""制御語で終わる区切り記号の後に空白を入れる (\lvertF のような連結を防ぐ)."""
    return d + ' ' if re.search(r'[A-Za-z]$', d) else d


def lr(l, r, body, star, size):
    l, r = sp(l), sp(r)
    if star:
        return rf'\left{l}{body}\right{r}'
    if size:
        return rf'{size}l{l}{body}{size}r{r}'
    return f'{l}{body}{r}'


def given(body, star, size):
    if star:
        mid = r'\;\middle|\;'
    elif size:
        mid = rf'\;{size}m|\;'
    else:
        mid = r'\mid '
    return body.replace(r'\given', mid)


class Expander:
    def __init__(self, macros):
        self.m = {d['name']: d for d in macros}
        names = sorted(self.m, key=len, reverse=True)
        self.pat = re.compile(r'\\(' + '|'.join(re.escape(n) for n in names) + r')(?![A-Za-z@])') if names else None
        self.warnings = []
        self.cur = '?'

    def warn(self, msg):
        self.warnings.append((self.cur, msg))

    def expand(self, s, lineno_of=None):
        if not self.pat:
            return s
        out = []
        i = 0
        while True:
            m = self.pat.search(s, i)
            if not m:
                out.append(s[i:])
                break
            out.append(s[i:m.start()])
            name = m.group(1)
            j = m.end()
            if lineno_of:
                self.cur = lineno_of(m.start())
            try:
                text, j = self.one(self.m[name], s, j)
            except Fail as e:
                self.warn(f'\\{name}: {e}')
                text, j = m.group(0), m.end()
            out.append(text)
            i = j
        return ''.join(out)

    def sub_args(self, tmpl, args, star, size, d):
        def rep(mm):
            if mm.group(1) == '|':
                bar = d.get('bar', r'\vert')
                if star:
                    return rf'\,\middle{bar}\,'
                if size:
                    return rf'\,{size}m{bar}\,'
                return rf'\,{bar}\,'
            return args[int(mm.group(1)) - 1]
        return re.sub(r'#(\d|\|)', rep, tmpl)

    def one(self, d, s, j):
        k = d['kind']
        if k == 'sym':
            return d['tex'], j
        if k == 'cmd':
            n = int(d.get('args', 0))
            args = []
            if 'opt' in d:
                if j < len(s) and s[j] == '[':
                    e = match(s, j, '[', ']')
                    args.append(s[j + 1:e - 1])
                    j = e
                else:
                    args.append(d['opt'])
                n -= 1
            for _ in range(n):
                a, j = take_brace(s, j)
                args.append(a)
            args = [self.expand(a) for a in args]
            return self.sub_args(d['body'], args, False, None, d), j
        if k == 'paired':
            star, size, j = take_star_opt(s, j)
            args = []
            for _ in range(int(d.get('args', 1))):
                a, j = take_brace(s, j)
                args.append(self.expand(a))
            body = self.sub_args(d.get('body', '#1'), args, star, size, d)
            if not body.strip() and 'empty' in d:
                body = d['empty']
            if d.get('given'):
                body = given(body, star, size)
            text = lr(d['l'], d['r'], body, star, size)
            text = self.sub_args(d.get('prefix', ''), args, star, size, d) + text + \
                self.sub_args(d.get('suffix', ''), args, star, size, d)
            return text, j
        if k == 'stat':
            name = d['name']
            star, size, j = take_star_opt(s, j)
            main, j = take_brace(s, j)
            sub = sup = None
            kk = j
            while kk < len(s) and s[kk] in ' \t':
                kk += 1
            if kk < len(s) and s[kk] == '{':          # 旧形式 \Ex{sub}{sup}{main}
                sub = main
                sup, k2 = take_brace(s, kk)
                main, j = take_brace(s, k2)
                if not sub.strip() and sup.strip():    # \Ex{}{D}{..} は E_{D}[..] と解釈
                    sub, sup = sup, None
                self.warn(f'旧形式 \\{name}{{{sub}}}{{{sup or ""}}}{{{main[:30]}}} を 添字版に変換')
            else:
                if j < len(s) and s[j] == '[':
                    e = match(s, j, '[', ']')
                    sub = s[j + 1:e - 1]
                    j = e
                if j < len(s) and s[j] == '(':
                    e = match(s, j, '(', ')')
                    sup = s[j + 1:e - 1]
                    j = e
            head = d['head']
            if sub and sub.strip():
                head += f'_{{{self.expand(sub)}}}'
            if sup and sup.strip():
                head += f'^{{{self.expand(sup)}}}'
            return head + lr(d['l'], d['r'], given(self.expand(main), star, size), star, size), j
        if k == 'optsub':
            if j < len(s) and s[j] == '[':
                e = match(s, j, '[', ']')
                return d['base'] + f'_{{{self.expand(s[j + 1:e - 1])}}}', e
            return d['base'], j
        if k == 'bigo':
            sym = d['sym']
            if j < len(s) and s[j] == '[':
                e = match(s, j, '[', ']')
                sym += rf'_{{\mathrm{{{s[j + 1:e - 1]}}}}}'
                j = e
            if j < len(s) and s[j] == '(':
                e = match(s, j, '(', ')')
                sym += rf'\left({self.expand(s[j + 1:e - 1])}\right)'
                j = e
            return sym, j
        raise Fail(f'unknown kind {k}')


# MathJax 3 で未対応 / 要確認な命令 (一般的なもの). 案件に合わせて足してよい
RISKY = {
    r'\\MoveEqLeft': 'mathtools: MathJax の mathtools 拡張で要確認 (align の先頭行の字下げ)',
    r'\\lefteqn': '未対応: split / aligned 形式に書き換えが必要',
    r'\\mathclap': 'mathtools 拡張で要確認',
    r'\\coloneqq|\\eqqcolon': 'mathtools 拡張で要確認 (\\mathrel{:=} への置換が安全)',
    r'\\put|\\unitlength|\\begin\{picture\}': '未対応: picture 環境 (図は画像にする)',
    r'\\epsfile|\\psfig': '未対応: 旧式の図読み込み',
    r'\\begin\{eqnarray\*?\}': 'eqnarray は align に変更を推奨',
    r'\\begin\{(dcases|cases\*)\}': 'mathtools の cases 系: 拡張で要確認',
    r'\\boldmath': '未対応: \\boldsymbol に置換',
    r'\\ifrac|\\sfrac|\\dsfrac': '独自/xfrac の分数',
    r'\\label\{': 'LaTeX の \\label: quarto の相互参照 {#eq-..} への変換が必要',
    r'\\(eq)?ref\{': 'LaTeX の \\ref: quarto の @eq-.. への変換が必要',
    r'\\cite|\\fullcite|\\nocite': '文献引用: quarto の @key / [@key] へ変換',
    r'\\todo|\\fixme': 'fixme パッケージ依存 (HTML では無効)',
    r'\\index\{': 'TeX 専用 (HTML では export latex ブロックに入れる)',
    r'\\text\{[^}]*\\\(': '\\text 内の入れ子数式: MathJax で崩れる可能性',
    r'\\mbox\{[^}]*\\\(|\\mbox\{[^}]*\$': '\\mbox 内の入れ子数式',
    r'\\protect': '見出し内の \\protect\\ref',
    r'\\(cal|rm|bf|it)\b': '旧式の書体命令: \\mathcal \\mathrm \\mathbf \\mathit へ',
    r'\\hspace\{[^}]*(textwidth|linewidth)': 'MathJax 非対応の長さ: em などに置換',
}


def init_from_preamble(path):
    """プリアンブルの単純な定義を拾って定義ファイルの雛形を作る (複雑なものは todo に残す)."""
    t = open(path, encoding='utf8').read()
    t = '\n'.join(l for l in t.split('\n') if not l.lstrip().startswith('%'))
    macros, todo = [], []
    pat = re.compile(r'\\(newcommand|renewcommand|providecommand|DeclareMathOperator\*?|DeclarePairedDelimiterXPP|'
                     r'DeclarePairedDelimiterX|DeclarePairedDelimiter|NewDocumentCommand|DeclareDocumentCommand)\*?')

    def name_at(i):
        while t[i] in ' \t\n':
            i += 1
        if t[i] == '{':
            e = match(t, i, '{', '}')
            return t[i + 1:e - 1].strip().lstrip('\\'), e
        m = re.match(r'\\([A-Za-z@]+|.)', t[i:])
        return m.group(1), i + m.end()

    def opt_at(i):
        while i < len(t) and t[i] in ' \t\n':
            i += 1
        if i < len(t) and t[i] == '[':
            e = match(t, i, '[', ']')
            return t[i + 1:e - 1], e
        return None, i

    def brace_at(i):
        while i < len(t) and t[i] in ' \t\n':
            i += 1
        if i < len(t) and t[i] == '{':
            e = match(t, i, '{', '}')
            return t[i + 1:e - 1], e
        if i < len(t) and t[i] == '\\':
            m = re.match(r'\\([A-Za-z@]+|.)', t[i:])
            return m.group(0), i + m.end()
        if i < len(t):
            return t[i], i + 1
        raise Fail('eof')

    for m in pat.finditer(t):
        kind = m.group(1)
        try:
            name, i = name_at(m.end())
            if kind.startswith('DeclareMathOperator'):
                txt, i = brace_at(i)
                macros.append({'name': name, 'kind': 'sym', 'tex': rf'\operatorname{{{txt}}}'})
            elif kind in ('newcommand', 'renewcommand', 'providecommand'):
                n, i = opt_at(i)
                dflt = None
                if n is not None:
                    d, i2 = opt_at(i)
                    if d is not None:
                        dflt, i = d, i2
                body, i = brace_at(i)
                if n is None:
                    macros.append({'name': name, 'kind': 'sym', 'tex': body})
                else:
                    e = {'name': name, 'kind': 'cmd', 'args': int(n), 'body': body}
                    if dflt is not None:
                        e['opt'] = dflt
                    macros.append(e)
            elif kind == 'DeclarePairedDelimiter':
                l, i = brace_at(i)
                r, i = brace_at(i)
                macros.append({'name': name, 'kind': 'paired', 'l': l, 'r': r})
            elif kind == 'DeclarePairedDelimiterX':
                n, i = opt_at(i)
                l, i = brace_at(i)
                r, i = brace_at(i)
                body, i = brace_at(i)
                if '\\' in re.sub(r'\\(given|renewcommand|delimsize|SetSymbol)', '', body) and 'renewcommand' in body:
                    raise Fail('複雑な本体')
                macros.append({'name': name, 'kind': 'paired', 'l': l, 'r': r, 'args': int(n or 1), 'body': body})
            else:
                todo.append(f'\\{name} ({kind}): 手で定義する (stat / optsub / bigo / cmd に当てはまるか検討)')
        except Exception as e:
            todo.append(f'\\{kind} ... 読めなかった ({e}): ' + t[m.start():m.start() + 60].replace('\n', ' '))
    print(json.dumps({'_todo': todo, 'macros': macros}, ensure_ascii=False, indent=1))


def main():
    ap = argparse.ArgumentParser(description='自作マクロを MathJax が読める TeX に展開する')
    ap.add_argument('input', nargs='?')
    ap.add_argument('-m', '--macros', help='マクロ定義ファイル (JSON)')
    ap.add_argument('-o', '--output')
    ap.add_argument('--from-line', type=int, default=1, help='この行より前 (プリアンブル) は触らない')
    ap.add_argument('--report', action='store_true', help='展開後に未対応/要確認の命令を一覧する')
    ap.add_argument('--init', metavar='PREAMBLE', help='プリアンブルから定義ファイルの雛形を標準出力に作る')
    a = ap.parse_args()
    if a.init:
        init_from_preamble(a.init)
        return
    if not a.input:
        ap.error('INPUT が必要です')
    macros = []
    if a.macros:
        macros = json.load(open(a.macros, encoding='utf8'))['macros']
    ex = Expander(macros)
    lines = open(a.input, encoding='utf8').read().split('\n')
    head = '\n'.join(lines[:a.from_line - 1])
    body = '\n'.join(lines[a.from_line - 1:])
    starts = [0]
    for l in body.split('\n'):
        starts.append(starts[-1] + len(l) + 1)
    lineno = lambda pos: a.from_line + bisect.bisect_right(starts, pos) - 1
    blines = body.split('\n')
    saved = {}
    for k, l in enumerate(blines):
        if l.lstrip().startswith(('#', '%')) and not l.lstrip().startswith(('#+',)):
            saved[k] = l
            blines[k] = ''
    new = ex.expand('\n'.join(blines), lineno)
    nl = new.split('\n')
    if len(nl) == len(blines):          # マスクした行は添字で復元できる (展開で行が増えない場合のみ)
        for k, l in saved.items():
            nl[k] = l
        new = '\n'.join(nl)
    else:
        print('[error] 展開で行数が変わったためコメント行を復元できません', file=sys.stderr)
    if a.output:
        open(a.output, 'w', encoding='utf8').write((head + '\n' if head else '') + new)
    elif not a.report:
        sys.stdout.write(new)
    for ln, msg in ex.warnings:
        print(f'[warn] line {ln}: {msg}', file=sys.stderr)
    if a.report:
        for pat, why in RISKY.items():
            hits = [a.from_line + i for i, l in enumerate(new.split('\n'))
                    if re.search(pat, l) and not l.lstrip().startswith(('#', '%'))]
            if hits:
                print(f'{pat:40s} {len(hits):4d} 件  {why}\n    例: {hits[:8]}')


if __name__ == '__main__':
    main()
