# Idea: parse open-api to generate commands to parse any api

let kiki_api = (curl https://api-dev.dojo.codes/openapi.json | from json)

def get-schemas [url: string] {
    ($url | get components | get schemas)
}

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

def generate-code [infos: record parsed_api: record] {
    let commands = ($parsed_api | par-each { |r| generate-command ($infos | get title) $r })
    $commands | save $"($infos | get title)_($infos | get version).nu"
}

def generate-command [title: string row: record] {
    let def_name = generate-def-name $row
    let desc = ($row | get description)
    $'#($desc)
      def "($title) ($def_name)" [] {}
     '
}

# {...} -> get-address_address_txs-pending
def generate-def-name [row: record] {
    $"($row | get method):($row | get route)"
}

# TODO: are all arguments in path required ?
# /address/{address} ~> /address/0xdfb50d6eccb4f5e529f7024a137ab7d3c82dd693
def splice-path [route: string params: list] {
    $params | transpose k v | reduce -f $route { |r, acc| $acc | str replace $'{($r | get k)}' $'($r | get v)'}
}

# /address ~> /address?noinput=true
def splice-query [route: string params: list] {
    $params | transpose k v | reduce -f ($route ++ '?') { |r, acc| $"($acc)($r | get k)=($r | get v)&" } | str substring 0..($string | length | -1)
}

# def $operation-id [ parameters: record ] {
#   CURL -X $method ($base-url)($route)
# }
#
#

#/campaign/{id}/is_self_participant/{address}
