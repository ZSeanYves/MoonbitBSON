///|
#borrow(path)
extern "c" fn read_fuzz_input(path : Bytes) -> Bytes = "moonbit_bson_read_file"

///|
fn main {
  let args = @env.args()
  if args.length() > 0 {
    let path = @utf8.encode(args[args.length() - 1])
    let input = read_fuzz_input(path)
    try @bson.decode(input) catch {
      _ => ()
    } noraise {
      _ => ()
    }
  }
}
