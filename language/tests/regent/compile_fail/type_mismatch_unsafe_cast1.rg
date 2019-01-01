-- Copyright 2019 Stanford University
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- fails-with:
-- type_mismatch_unsafe_cast1.rg:24: unsafe_cast requires single ptr type as argument 1, got ptr(int32, $r, $s)
-- var y = unsafe_cast(ptr(int, r, s), x)
--                     ^

import "regent"

task f(r : region(int), s : region(int))
  var x = 5
  var y = unsafe_cast(ptr(int, r, s), x)
end
f:compile()
