class Util {
  static int mod(int n, int modulus) {
    n = n % modulus;
    if (n < 0) n += modulus;
    return n;
  }
}
