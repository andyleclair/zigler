defmodule Zig.Type.Slice do
  alias Zig.Type
  use Type

  import Type, only: :macros

  defstruct [:child, :repr, has_sentinel?: false]

  @type t :: %__MODULE__{
          child: Type.t(),
          repr: String.t(),
          has_sentinel?: boolean
        }

  def from_json(
        %{"child" => child, "has_sentinel" => has_sentinel?, "repr" => repr},
        module
      ) do
    %__MODULE__{
      child: Type.from_json(child, module),
      has_sentinel?: has_sentinel?,
      repr: repr
    }
  end

  # TYPE SPEC STUFF

  def render_elixir_spec(%{child: ~t(u8)}, :return, opts) do
    case opts do
      %{as: :list} ->
        [Type.render_elixir_spec(~t(u8), :return, opts)]

      _ ->
        binary_form(~t(u8))
    end
  end

  def render_elixir_spec(%{child: ~t(u8)}, :param, opts) do
    quote context: Elixir do
      [unquote(Type.render_elixir_spec(~t(u8), :param, opts))] | unquote(binary_form(~t(u8)))
    end
  end

  def render_elixir_spec(%{child: child}, context, opts) do
    case {context, opts} do
      {:return, %{as: :binary}} ->
        binary_form(child) || raise "unreachable"

      {:return, %{as: type}} when type in ~w(default list)a ->
        [Type.render_elixir_spec(child, :return, [])]

      {:param, _} ->
        if binary_form(child) do
          quote context: Elixir do
            unquote([Type.render_elixir_spec(child, :param, [])]) | unquote(binary_form(child))
          end
        else
          [Type.render_elixir_spec(child, :param, [])]
        end
    end
  end

  defp binary_form(~t(u8)) do
    quote do
      binary()
    end
  end

  defp binary_form(%Type.Integer{bits: bits}) do
    quote context: Elixir do
      <<_::_*unquote(Type.Integer._next_power_of_two_ceil(bits))>>
    end
  end

  defp binary_form(%Type.Float{bits: bits}) do
    quote context: Elixir do
      <<_::_*unquote(bits)>>
    end
  end

  defp binary_form(%Type.Struct{packed: size}) when is_integer(size) do
    quote context: Elixir do
      <<_::_*unquote(size * 8)>>
    end
  end

  defp binary_form(_), do: nil

  # ETC

  def get_allowed?(slice), do: Type.get_allowed?(slice.child)
  def make_allowed?(slice), do: Type.make_allowed?(slice.child)
  def can_cleanup?(_), do: true

  def render_payload_options(_, _, _), do: Type._default_payload_options()
  def render_return(_, opts), do: Type._default_return(opts)
  def marshal_param(_, _, _, _), do: Type._default_marshal()
  def marshal_return(_, _, _), do: Type._default_marshal()

  def of(child, opts \\ []), do: struct(__MODULE__, [child: child] ++ opts)
end
