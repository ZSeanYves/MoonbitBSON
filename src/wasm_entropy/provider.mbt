///|
/// The embedding host must provide this WebAssembly import with secure random
/// bytes (for example WASI `random_get` or a host crypto API).
fn secure_random_word() -> UInt = "moonbit:bson" "secure_random_u32"

///|
/// Install the Wasm host entropy adapter used by `ObjectId::new`.
/// The imported function is sampled four bytes at a time and therefore must
/// be backed by a cryptographically secure host source.
pub fn install() -> Unit {
  @bson.install_secure_entropy_provider(fn(count : Int) -> Bytes? {
    Some(Bytes::makei(count, index => {
      let word = secure_random_word()
      (word >> ((index % 4) * 8)).to_byte()
    }))
  })
}

///|
pub fn clear() -> Unit {
  @bson.clear_secure_entropy_provider()
}
