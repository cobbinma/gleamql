-module(gleamql_ffi).
-export([placeholder/0]).

% Returns undefined which can be passed around without evaluation.
% This is safe because it's only used to extract field structure from
% ObjectBuilder continuations and is never actually decoded.
placeholder() -> undefined.
