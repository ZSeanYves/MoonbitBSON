///|
priv struct JsonNumberCursor {
  values : Array[String]
  mut index : Int
}

///|
fn restore_json_number_reprs(value : Json, source : String) -> Json {
  let cursor : JsonNumberCursor = {
    values: collect_json_number_reprs(source),
    index: 0,
  }
  restore_json_number_reprs_in_value(value, cursor)
}

///|
fn restore_json_number_reprs_in_value(
  value : Json,
  cursor : JsonNumberCursor,
) -> Json {
  match value {
    Number(number, ..) => {
      let repr = cursor.values[cursor.index]
      cursor.index += 1
      Json::number(number, repr~)
    }
    Array(values) =>
      Json::array(
        values.map(value => restore_json_number_reprs_in_value(value, cursor)),
      )
    Object(values) => {
      let restored : Array[(String, Json)] = []
      for key, value in values {
        restored.push((key, restore_json_number_reprs_in_value(value, cursor)))
      }
      Json::object(Map(restored))
    }
    String(value) => Json::string(value)
    True => Json::boolean(true)
    False => Json::boolean(false)
    Null => Json::null()
  }
}

///|
fn collect_json_number_reprs(source : String) -> Array[String] {
  let values : Array[String] = []
  let mut index = 0
  let mut in_string = false
  let mut escaped = false
  while index < source.length() {
    let code = source[index]
    if in_string {
      if escaped {
        escaped = false
      } else if code == '\\' {
        escaped = true
      } else if code == '"' {
        in_string = false
      }
      index += 1
    } else if code == '"' {
      in_string = true
      index += 1
    } else if code == '-' || code is ('0'..='9') {
      let start = index
      index += 1
      while index < source.length() && is_json_number_code(source[index]) {
        index += 1
      }
      values.push(source[start:index].to_owned())
    } else {
      index += 1
    }
  }
  values
}

///|
fn is_json_number_code(code : UInt16) -> Bool {
  code is ('0'..='9' | '.' | 'e' | 'E' | '+' | '-')
}
