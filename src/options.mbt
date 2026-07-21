///|
pub struct EncodeOptions {
  max_depth : Int
  max_size : Int
} derive(Eq, Debug)

///|
pub fn EncodeOptions::new(
  max_depth? : Int = 100,
  max_size? : Int = 16 * 1024 * 1024,
) -> EncodeOptions {
  { max_depth, max_size }
}

///|
pub fn EncodeOptions::max_depth(self : EncodeOptions) -> Int {
  self.max_depth
}

///|
pub fn EncodeOptions::max_size(self : EncodeOptions) -> Int {
  self.max_size
}

///|
pub struct DecodeOptions {
  max_depth : Int
  max_size : Int
  require_canonical_array_keys : Bool
} derive(Eq, Debug)

///|
pub fn DecodeOptions::new(
  max_depth? : Int = 100,
  max_size? : Int = 16 * 1024 * 1024,
  require_canonical_array_keys? : Bool = false,
) -> DecodeOptions {
  { max_depth, max_size, require_canonical_array_keys }
}

///|
pub fn DecodeOptions::max_depth(self : DecodeOptions) -> Int {
  self.max_depth
}

///|
pub fn DecodeOptions::max_size(self : DecodeOptions) -> Int {
  self.max_size
}

///|
pub fn DecodeOptions::require_canonical_array_keys(
  self : DecodeOptions,
) -> Bool {
  self.require_canonical_array_keys
}
