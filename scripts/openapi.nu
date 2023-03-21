# Idea: parse open-api to generate commands to parse any api

let kiki_api = (curl https://api-dev.dojo.codes/openapi.json | from json)

def get-schemas [url: string] {
    ($url | get components | get schemas)
}

def zoom [url: string] {
    let t = ($url | get paths | transpose url val)

    def get-url [path: table] {
        $path | get url
    }

    def get-methods [path: table] {
        $path | get val | columns
    }

    def get-operation-ids [method: table] {
        $method | get operationId
    }

    ($t | par-each { |v|
        let url = get-url $v
        let methods = get-methods $v
        let operation_ids = ($methods | par-each {|m| get-operation-ids ($v | get val | get $m)})
        let zipped = ($methods | zip $operation_ids)
        let final = ($zipped | par-each { |z| $z | append $url })
        {method: ($final | get 0) operation-id: ($final | get 1) route: ($final | get 2)}
    })
}


