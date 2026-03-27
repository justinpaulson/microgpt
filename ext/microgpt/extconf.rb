require 'mkmf'

$CFLAGS << ' -O3 -ffast-math'

# Use Apple Accelerate framework (BLAS) on macOS for hardware-accelerated matmul
if RUBY_PLATFORM =~ /darwin/
  $CFLAGS << ' -DHAVE_ACCELERATE -DACCELERATE_NEW_LAPACK'
  $LDFLAGS << ' -framework Accelerate'
end

create_makefile('native')
