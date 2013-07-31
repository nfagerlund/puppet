Resource Type
=============

See the end of this page for the source manifest used to generate all example responses.

Find
----

    GET /:environment/resource_type/:name

### Parameters

None

### Responses

#### Resource Type Found

    GET /env/resource_type/athing

    HTTP 200 OK
    Content-Type: text/pson

    {
      "line": 7,
      "file": "/etc/puppet/manifests/site.pp",
      "name":"athing",
      "kind":"class"
    }

#### Resource Type Not Found

    GET /env/resource_type/resource_type_does_not_exist

    HTTP 404 Not Found: Could not find resource_type resource_type_does_not_exist
    Content-Type: text/plain

    Not Found: Could not find resource_type resource_type_does_not_exist

#### No Resource Type Name Given

    GET /env/resource_type/

    HTTP/1.1 400 No request key specified in /env/resource_type/
    Content-Type: text/plain

    No request key specified in /env/resource_type/

Search
------

List all resource types matching a regular expression:

    GET /:environment/resource_types/:search_string

`search_string` is a Ruby regular expression. Surrounding slashes are
stripped. It can also be the string `*`, which will match all
resource types. It is required.

### Parameters

* `kind`: Filter the returned resource types by the `kind` field.
  Valid values are `class`, `node`, and `defined_type`.

### Responses

#### Search With Results

    GET /env/resource_types/*

    HTTP 200 OK
    Content-Type: text/pson

    [
      {
        "file": "/etc/puppet/manifests/site.pp",
        "kind": "class",
        "line": 7,
        "name": "athing"
      },
      {
        "doc": "An example class\n",
        "file": "/etc/puppet/manifests/site.pp",
        "kind": "class",
        "line": 11,
        "name": "bthing",
        "parent": "athing"
      },
      {
        "file": "/etc/puppet/manifests/site.pp",
        "kind": "defined_type",
        "line": 1,
        "name": "hello",
        "parameters": {
          "a": "{key2 => \"val2\", key => \"val\"}",
          "message": "$title"
        }
      },
      {
        "file": "/etc/puppet/manifests/site.pp",
        "kind": "node",
        "line": 14,
        "name": "web01.example.com"
      },
      {
        "file": "/etc/puppet/manifests/site.pp",
        "kind": "node",
        "line": 17,
        "name": "default"
      }
    ]


#### Search Not Found

    GET /env/resource_types/pattern.that.finds.no.resources

    HTTP/1.1 404 Not Found: Could not find instances in resource_type with 'pattern.that.finds.no.resources'
    Content-Type: text/plain

    Not Found: Could not find instances in resource_type with 'pattern.that.finds.no.resources'

#### No Search Term Given

    GET /env/resource_types/

    HTTP/1.1 400 No request key specified in /env/resource_types/
    Content-Type: text/plain

    No request key specified in /env/resource_types/

#### Search Term Is an Invalid Regular Expression

Searching on `[-` for instance.

    GET /env/resource_types/%5b-

    HTTP/1.1 400 Invalid regex '[-': premature end of char-class: /[-/
    Content-Type: text/plain

    Invalid regex '[-': premature end of char-class: /[-/

### Examples

List all classes:

    GET /:environment/resource_types/*?kind=class

List matching a regular expression:

    GET /:environment/resource_types/foo.*bar

Schema
------

A resource_type response body has has the following fields, of which only name
and kind are guaranteed to be present:

    doc: string
        Any documentation comment from the type definition

    line: integer
        The line number where the type is defined

    file: string
        The full path of the file where the type is defined

    name: string
        The fully qualified name

    kind: string, one of "class", "node", or "defined_type"
        The kind of object the type represents

    parent: string
        If the type inherits from another type, the name of that type

    parameters: hash{string => (string or "null")}
        The default arguments to the type. If an argument has no default value,
        the value is represented by a literal "null" (without quotes in pson).
        Default values are the string representation of that value, even for more
        complex structures (e.g. the hash { key => 'val', key2 => 'val2' } would
        be represented in pson as "{key => \"val\", key2 => \"val2\"}".

Source
------

Example site.pp used to generate all the responses in this file:

    define hello ($message = $title, $a = { key => 'val', key2 => 'val2' }) {
      notify {$message: }
    }

    hello { "there": }

    class athing {
    }

    # An example class
    class bthing inherits athing {
    }

    node 'web01.example.com' {}
    node default {}

