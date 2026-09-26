defmodule Foundry do
  @moduledoc false
  use Boundary, deps: [Exqlite.Sqlite3], exports: :all
end

defmodule Foundry.DurableStore do
  @moduledoc false
  use Boundary, deps: [Exqlite.Sqlite3], exports: :all, type: :strict
end

defmodule Foundry.Workflow do
  @moduledoc false
  use Boundary, deps: [], exports: :all, type: :strict
end

defmodule Foundry.ManualLane do
  @moduledoc false
  use Boundary, deps: [Foundry, Foundry.DurableStore, Foundry.Workflow], exports: :all
end

defmodule Foundry.Repair do
  @moduledoc false
  use Boundary, deps: [Foundry.DurableStore], exports: :all
end
