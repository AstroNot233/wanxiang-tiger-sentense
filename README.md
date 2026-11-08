# 万象虎·整句（wanxiang-tiger-sentense）

虎码整句输入方案，两个方案共用同一份词库：

- `tiger` 万象虎·整句：整词码，2-4 码任意输入。
- `tiger_char` 万象虎·原码整句：单字序列，1 码字加 `'`，2-4 码照打，`_` 手动分词。

## 参考项目

| 项目 | 用到的部分 |
| :--- | :--- |
| [amzxyz/rime-wanxiang](https://github.com/amzxyz/rime-wanxiang) | 词库（`dicts/`）与语法模型；构建时把词条按虎码公式转写成整词码 |
| [lvyww/tiger-code](https://github.com/lvyww/tiger-code) | 虎码官方码表 `tables/tiger.txt`：字表、简码、词表原样收录，编码规则用于校验转写 |
| [zhhwux/wxzhh](https://github.com/zhhwux/wxzhh) | 整句思路：整词编码公式、`script_translator` 挂整词码 + 补全实现任意码 |
| [lvyww/tiger-sentense-rime](https://github.com/lvyww/tiger-sentense-rime) | 虎码官方整句版，可作为平行参考实现 |

## 提供的内容

```
config/default.yaml         最小 default 配置，schema_list 为 tiger、tiger_char
schema/tiger.schema.yaml    整句方案（整词码）
schema/tiger_char.schema.yaml       原码整句方案（单字序列）
tools/build.nu              组装 dist：配置层 + 词库 + 语法模型
tools/check.nu              用 rime_deployer 校验 dist
.github/workflows/build.yml 自动构建
```

`dist/` 产出九个文件：

```
default.yaml
tiger.schema.yaml
tiger_char.schema.yaml
tiger.dict.yaml             import 下面两份
tiger_seq.dict.yaml         import 字表（一码加 '）+ 转写词库
tiger_official.dict.yaml    官方字词表 171,074 条（3.7 万单字含简码、13.4 万词）
tiger_seq_chars.dict.yaml   同上，一码条目改写为 x'
tiger_words.dict.yaml       万象词库转写 1,624,478 条
wanxiang-lts-zh-hans.gram   语法模型
```

## 方案说明

- **编码**：每字取虎码全码（字表首条记录所在首字母家族内最长码）；整词二字 `AaAbBaBb`、三字 `AaBaCaCb`、四字以上 `AaBaCaZa`。用官方 13.4 万条词反查，公式与官方全码一致率 97.7%，其余为官方简码条目，简码已原样收录。
- **整词码方案**：`enable_completion` 打开，打 2、3 码即可补全整词码；连续输入按词切分并组句，排序由语法模型决定。
- **原码整句方案**：同一字的不同长度编码共用一个词频，逐字输入即出句；一码条目写成 `x'`，避免单字母切断码流，`_` 可手动分词。
- **权重**：官方表按表中顺序递减（`的`=1000000），万象转写词条沿用原词频。
- **标点**：schema 内置 `full_shape` / `half_shape` 中文标点映射，`ascii_punct` 切换中英标点。
- **造词与学习**：` `` ` 前缀自造词，上屏词条进入用户词典。
- **快捷键**：`-`/`=` 翻页，`Alt+←/→` 移动光标，`Control+w` 删一个词，`Shift+space` 切换方案。

## 构建

需要 `nu`；校验需要 `librime`。

```bash
git clone --depth 1 https://github.com/amzxyz/rime-wanxiang ../rime-wanxiang
git clone --depth 1 https://github.com/lvyww/tiger-code ../tiger-code

curl -fL --retry 3 -o wanxiang-lts-zh-hans.gram \
  https://github.com/amzxyz/RIME-LMDG/releases/download/LTS/wanxiang-lts-zh-hans.gram

nix shell nixpkgs#nushell -c \
  nu tools/build.nu -w ../rime-wanxiang -t ../tiger-code -o dist -g wanxiang-lts-zh-hans.gram

nix shell nixpkgs#nushell nixpkgs#librime -c nu tools/check.nu -d dist
```

`--quick` 只转写每个词库前 2000 条，用于验证配置。省略 `-g` 时会复用 `dist/` 里已有的语法模型。

## 部署

把 `dist/` 的内容放进 Rime 用户目录后重新部署：

- fcitx5：`~/.local/share/fcitx5/rime/`
- 小狼毫：`%APPDATA%\Rime\`
- 鼠须管：`~/Library/Rime/`

个人改动写在 `tiger.custom.yaml`，`tiger.schema.yaml` 会在下次构建时被覆盖。

## 许可证

| 内容 | 许可证 |
| :--- | :--- |
| rime-wanxiang 词库的转写结果 | CC BY 4.0，保留 [LICENSE](LICENSE) 与署名 |
| 虎码官方码表（tiger-code） | CC0-1.0 |
| tiger-sentense-rime | GPL-3.0，仅作参考 |
| wxzhh 万象虎 | 未附许可证；本仓库在文档中引用其设计并署名 |
| 本仓库自撰内容 | CC BY 4.0，署名 amzxyz/rime-wanxiang、lvyww/tiger-code、zhhwux/wxzhh |
