///|
struct CodegenUser {
  name : String
  age : Int64
  created : DateTime?
} derive(Eq, Debug)

///|
test "schema codegen round trips generated ToBson and FromBson" {
  let user = CodegenUser::{
    name: "Ada",
    age: 37L,
    created: Some(DateTime::from_millis(0L)),
  }
  let decoded : CodegenUser = from_bson(to_bson(user))
  assert_eq(decoded, user)
  let missing : CodegenUser = from_bson(
    Document(
      Document::new().set("name", String("Grace")).set("age_years", Int64(28L)),
    ),
  )
  assert_eq(missing.created, None)
}
