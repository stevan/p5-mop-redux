requires "Devel::CallParser" => "0";
requires "Hash::Util::FieldHash" => "0";
requires "Scalar::Util" => "0";
requires "XSLoader" => "0";
requires "mro" => "0";
requires "overload" => "0";
requires "parent" => "0";
requires "perl" => "v5.16.0";
requires "strict" => "0";
requires "version" => "0";
requires "warnings" => "0";

on 'test' => sub {
  requires "B::Deparse" => "0";
  requires "Capture::Tiny" => "0";
  requires "FindBin" => "0";
  requires "IO::Handle" => "0";
  requires "Test::More" => "0.88";
  requires "blib" => "0";
  requires "if" => "0";
  requires "lib" => "0";
};

on 'configure' => sub {
  requires "Devel::CallParser" => "0";
  requires "ExtUtils::MakeMaker" => "6.30";
};

on 'develop' => sub {
  requires "Devel::StackTrace" => "0";
  requires "Moose" => "0";
  requires "Moose::Util::TypeConstraints" => "0";
  requires "Package::Stash::XS" => "0.27";
  requires "Path::Class" => "0";
  requires "Pod::Coverage::TrustPod" => "0";
  requires "Test::EOL" => "0";
  requires "Test::NoTabs" => "0";
  requires "Test::Pod" => "1.41";
  requires "Test::Pod::Coverage" => "1.08";
};
