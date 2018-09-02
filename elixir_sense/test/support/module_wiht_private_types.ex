defmodule ModuleWithPrivateTypes do
  @opaque opaque_t :: atom
  @typep typep_t :: atom
  @type type_t :: atom
end
