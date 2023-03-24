# Idea: parse open-api to generate commands to parse any api

let kiki_api = (curl https://api-dev.dojo.codes/openapi.json | from json)

def get-schemas [url: string] {
    ($url | get components | get schemas)
}

let quoted_splice_path = "
def splice-path [route: string params: list] {
    if ($params | is-empty) {
        $route
    } else {
        $params | reduce -f $route { |r, acc| $acc | str replace $'{($r | get k)}' $'($r | get v)'}
    }
}
"

let quoted_splice_query = "
def splice-query [route: string params: list] {
    if ($params | is-empty) {
        $route
    } else {
        $params | reduce -f ($route ++ '?') { |r, acc| $"($acc)($r | get k)=($r | get v)&" } | trim-last-char
    }
}
"

def parse-open-api [url: string] {
    def get-url [path: table] {
        $path | get url
    }

    def get-methods [path: table] {
        $path | get val | columns
    }

    def get-description [method: table] {
        $method | get description
    }

    def get-parameters [method: table] {
        $method | get parameters
    }

    let t = ($url | get paths | transpose url val)
    ($t | par-each { |v|
        let url = get-url $v
        let methods = get-methods $v
        let description = ($methods | par-each {|m| try { get-description ($v | get val | get $m) } catch { "" } })
        let parameters = ($methods | par-each {|m| try { get-parameters ($v | get val | get $m)} catch { [[];[]] }})
        let zipped = ($methods | zip $description)
        let final = ($zipped | par-each { |z| $z | append $url | append $parameters })
        {method: ($final | get 0) description: ($final | get 1) route: ($final | get 2) parameters: ($final | range 3..)}
    })
}

def generate-code [infos: record parsed_api: record base_url: string] {
    let header = ($quoted_splice_path ++ $quoted_splice_query)
    let commands = ($parsed_api | par-each { |r| generate-command ($infos | get title) $r $base_url})
    $header ++ $commands | save $"($infos | get title)_($infos | get version).nu"
}

def generate-command [title: string row: record base_url: string] {
    let def_name = generate-def-name $row
    let desc = ($row | get description)
    let arguments = generate-arguments $row
    let body = generate-body $row $base_url
    $'#($desc)
      def "($title) ($def_name)" [($arguments)] {($body)}
     '
}

def generate-body [row: record base_url: string] {
    let route = $base_url ++ ($row | get route)
    let params = try {($row | get parameters | par-each { |p| $p | insert quote $'$($p | get name)'} | group-by in )} catch {[{}]}
    def to-kv [] {
       $in | reduce -f [{}] { |r, acc| $acc | append {k: ($r | get name) v: ($r | get quote)}  } | range 1..
    }
    let kv_path = try { ($params | get path | to-kv) } catch { [{}] }
    let kv_query = try { ($params | get query | to-kv) } catch { [{}] }
    let post_body = if ($row | get method) in ["get" "head"] { "" } else { "''" }
    $"
        let spliced_route = splice-query \(splice-path ($route) ($kv_path)\) ($kv_query)
        http ($row | get method) \$spliced_route ($post_body)
    "
}

def trim-last-char [] {
    $in | str substring 0..($in | str length | -1)
}

#TODO: refactor this shit xd
def generate-arguments [row: record] {
    let required_parameters = ($row | get parameters | filter {|row| get -i required | $in == true })
    let optional_parameters = ($row | get parameters | filter {|row| get -i required | $in == false })
    let spliced_required_params = ($required_parameters | reduce -f "" {|v, acc| $acc ++ (splice-parameter $v) ++ "\n"})
    let spliced_optional_params = ($optional_parameters | reduce -f $spliced_required_params {|v, acc| $acc ++ (splice-parameter $v) ++ "\n"} | trim-last-char)
    $spliced_optional_params
}

#TODO: type for real lmao
def get-nu-type [open_api_type: string] {
    "any"
}

#required│address│path|schema[string...]  ~> address: string
#optional│address│path|schema[string...]  ~> address?: string
def splice-parameter [param: record] {
    let name = ($param | get name)
    let nu_type = try {get-nu-type ($param | get schema | get type)} catch { "any" }
    let splice_optional = if ($param | get required) {""} else {"?"}
    $"($name)($splice_optional): ($nu_type)"
}

# {...} -> get-address_address_txs-pending
def generate-def-name [row: record] {
    $"($row | get method):($row | get route)"
}

# TODO: are all arguments in path required ?
# /address/{address} ~> /address/0xdfb50d6eccb4f5e529f7024a137ab7d3c82dd693
def splice-path [route: string params: list] {
    if ($params | is-empty) {
        $route
    } else {
        $params | reduce -f $route { |r, acc| $acc | str replace $'{($r | get k)}' $'($r | get v)'}
    }
}

# /address ~> /address?noinput=true
def splice-query [route: string params: list] {
    if ($params | is-empty) {
        $route
    } else {
        $params | reduce -f ($route ++ '?') { |r, acc| $"($acc)($r | get k)=($r | get v)&" } | trim-last-char
    }
}

