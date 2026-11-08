#!/usr/bin/env nu

const SOURCE_DICTS = ['jichu' 'duoyin' 'diming' 'mingren' 'yiren']
const OFFICIAL_WEIGHT_BASE = 1000000

def dict-rows [path: path] {
  open --raw $path
  | str replace --all (char cr) ''
  | split row (char nl)
  | skip until '...'
  | skip 1
  | where {|l| ($l | str trim) != '' and not ($l | str trim | str starts-with '#') }
}

def table-rows [path: path] {
  open --raw $path
  | str replace --all (char cr) ''
  | split row (char nl)
  | skip until '[Data]'
  | skip 1
  | where {|l| $l | str contains (char tab) }
  | each {|l| let f = ($l | split row (char tab)); {code: $f.0, text: $f.1} }
}

def split-fields [line: string] {
  $line | split row (char tab)
}

# 每字全码：首条记录所在首字母家族内最长码，同长取表中靠前者
def char-codes [rows: table] {
  let total = ($rows | length)
  let entries = ($rows | enumerate | each {|r|
    {
      text: $r.item.text
      code: $r.item.code
      idx: $r.index
      head: ($r.item.code | str substring 0..<1)
      len: ($r.item.code | str length)
    }
  })

  let firsts = ($entries | uniq-by text | select text head | rename first_head)
  let heads = ($firsts | transpose -r -d | into record)
  let canon = ($entries
    | insert fhead {|e| $heads | get -o $e.text }
    | where {|e| $e.head == $e.fhead }
    | insert order {|e| ($e.len * 1000000000) + ($total - $e.idx) }
    | sort-by order --reverse
    | uniq-by text
    | select text code)

  $canon | transpose -r -d | into record
}

# 整词码：二字 AaAbBaBb，三字 AaBaCaCb，四字以上 AaBaCaZa；非汉字字符忽略
def word-code [codes: record, word: string] {
  let han = ($word | split chars | where {|c| $c =~ '\p{Han}' } | collect)
  if ($han | length) == 0 { return null }
  let cs = ($han | each {|c| $codes | get -o $c } | collect)
  if ($cs | length) != ($han | length) { return null }
  let n = ($cs | length)
  if $n == 1 {
    $cs.0
  } else if $n == 2 {
    ($cs.0 | str substring 0..<2) ++ ($cs.1 | str substring 0..<2)
  } else if $n == 3 {
    ($cs.0 | str substring 0..<1) ++ ($cs.1 | str substring 0..<1) ++ ($cs.2 | str substring 0..<2)
  } else {
    ($cs.0 | str substring 0..<1) ++ ($cs.1 | str substring 0..<1) ++ ($cs.2 | str substring 0..<1) ++ (($cs | last) | str substring 0..<1)
  }
}

def write-header [name: string] {
  [
    '---'
    $"name: ($name)"
    'version: "2026.11"'
    'sort: by_weight'
    'columns:'
    '  - text'
    '  - code'
    '  - weight'
    '...'
  ] | str join (char nl)
}

def export-official [rows: table, out: path] {
  let body = ($rows | enumerate | each {|r|
    $"($r.item.text)\t($r.item.code)\t($OFFICIAL_WEIGHT_BASE - $r.index)"
  } | str join (char nl))

  (write-header 'tiger_official') ++ (char nl) ++ $body ++ (char nl) | save --force $out
  $rows | length
}

# 一码条目加 ' 后缀；同一字的不同长度编码共用一个词频，避免长码被表面位置压低
def export-seq-chars [rows: table, out: path] {
  let ranked = ($rows
    | enumerate
    | each {|r| {text: $r.item.text, w: ($OFFICIAL_WEIGHT_BASE - $r.index)} }
    | sort-by w --reverse
    | uniq-by text)
  let wmap = ($ranked | transpose -r -d | into record)

  let body = ($rows | each {|r|
    let code = if ($r.code | str length) == 1 { $r.code + "'" } else { $r.code }
    let w = ($wmap | get -o $r.text)
    $"($r.text)\t($code)\t($w)"
  } | str join (char nl))

  (write-header 'tiger_seq_chars') ++ (char nl) ++ $body ++ (char nl) | save --force $out
  $rows | length
}

def export-words [codes: record, dicts: list<path>, out: path, limit: int] {
  let lines = ($dicts | par-each {|d|
      let rows = (dict-rows $d)
      let picked = (if $limit > 0 { $rows | first $limit } else { $rows })
      $picked
      | chunks 25000
      | par-each {|chunk|
          $chunk | each {|l|
            let f = (split-fields $l)
            if ($f | length) < 3 { return null }
            let code = (word-code $codes $f.0)
            if $code == null { return null }
            $"($f.0)\t($code)\t($f.2)"
          }
        }
      | flatten
      | compact
    }
    | flatten)

  (write-header 'tiger_words') ++ (char nl) ++ ($lines | str join (char nl)) ++ (char nl) | save --force $out
  $lines | length
}

def write-tiger-dict [out: path, name: string, imports: list<string>] {
  let tables = ($imports | each {|t| $"  - ($t)" })
  let body = ([
    '---'
    $"name: ($name)"
    'version: "2026.11"'
    'sort: by_weight'
    'use_preset_vocabulary: false'
    'import_tables:'
  ] ++ $tables ++ ['...']) | str join (char nl)
  $body | save --force $out
}

def main [
  --wanxiang (-w): path = '../rime-wanxiang'
  --tiger-code (-t): path = '../tiger-code'
  --out (-o): path = 'dist'
  --gram (-g): path = ''
  --quick (-q)
] {
  let limit = (if $quick { 2000 } else { 0 })
  let w = ($wanxiang | path expand)
  let t = ($tiger_code | path expand)
  let dst = ($out | path expand)

  if not ($w | path join 'dicts/jichu.dict.yaml' | path exists) {
    error make { msg: $"($w) 不像 rime-wanxiang 检出目录" }
  }
  if not ($t | path join 'tables/tiger.txt' | path exists) {
    error make { msg: $"($t) 缺少 tables/tiger.txt" }
  }
  if $gram != '' and not (($gram | path expand) | path exists) {
    error make { msg: $"语法模型不存在：($gram | path expand)" }
  }

  let model = (if $gram != '' {
    ($gram | path expand)
  } else if ($dst | path join 'wanxiang-lts-zh-hans.gram' | path exists) {
    let cache = (($env.TMPDIR? | default '/tmp') | path join 'wanxiang-gram-cache.bin')
    cp ($dst | path join 'wanxiang-lts-zh-hans.gram') $cache
    $cache
  } else {
    ''
  })

  if ($dst | path exists) and (not ($dst | is-empty)) and (not ($dst | path join 'tiger.dict.yaml' | path exists)) {
    error make { msg: $"($dst) 已存在且不像构建输出，拒绝覆盖" }
  }

  rm -rf $dst
  mkdir $dst

  cp ($env.FILE_PWD | path join '..' 'config' 'default.yaml') $dst
  cp ($env.FILE_PWD | path join '..' 'schema' 'tiger.schema.yaml') $dst
  cp ($env.FILE_PWD | path join '..' 'schema' 'tiger_char.schema.yaml') $dst

  let rows = (table-rows ($t | path join 'tables/tiger.txt'))
  let char_rows = ($rows | where {|r| ($r.text | split chars | length) == 1 })
  let codes = (char-codes $char_rows)
  print $"码表 ($rows | length) 条，单字 ($char_rows | length) 条，编码字 ((($codes | columns) | length)) 个"

  let official = (export-official $rows ($dst | path join 'tiger_official.dict.yaml'))
  let seq_chars = (export-seq-chars $rows ($dst | path join 'tiger_seq_chars.dict.yaml'))
  print $"官方字词表 ($official) 条，原码整句字表 ($seq_chars) 条"

  let sources = ($SOURCE_DICTS | each {|d| $w | path join 'dicts' $"($d).dict.yaml" } | where {|p| $p | path exists })
  let count = (export-words $codes $sources ($dst | path join 'tiger_words.dict.yaml') $limit)
  print $"转写词库 ($count) 条"

  write-tiger-dict ($dst | path join 'tiger.dict.yaml') 'tiger' ['tiger_official' 'tiger_words']
  write-tiger-dict ($dst | path join 'tiger_seq.dict.yaml') 'tiger_seq' ['tiger_seq_chars' 'tiger_words']

  if $model != '' {
    cp $model ($dst | path join 'wanxiang-lts-zh-hans.gram')
  }

  print $"完成：($dst)"
}
