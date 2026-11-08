#!/usr/bin/env nu

def main [
  --dist (-d): path = 'dist'
  --user (-u): path = '.check'
] {
  let src = ($dist | path expand)
  let usr = ($user | path expand)

  if not ($src | path join 'tiger.schema.yaml' | path exists) {
    error make { msg: $"($src) 不是构建输出目录" }
  }
  if (which rime_deployer | is-empty) {
    error make { msg: '缺少 rime_deployer' }
  }

  mkdir $usr
  let out = (^rime_deployer --build $usr $src ($usr | path join 'build') | complete)
  let errs = ($out.stderr | lines | where {|l| $l =~ '^E20' or $l =~ 'error' })

  if not ($errs | is-empty) {
    $errs | each {|l| print $"  ($l)" }
    exit 1
  }
  if $out.exit_code != 0 {
    print $"rime_deployer 退出码 ($out.exit_code)"
    exit 1
  }

  let built = (ls ($usr | path join 'build') | where {|f| $f.name | str ends-with '.bin' } | get name | each {|p| $p | path basename })
  print $"部署通过：($built | str join ', ')"
}
