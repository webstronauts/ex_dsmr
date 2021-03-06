defmodule DSMR.Telegram do
  @type t() :: %__MODULE__{
          header: DSMR.Telegram.Header.t(),
          checksum: DSMR.Telegram.Checksum.t(),
          data: [DSMR.Telegram.COSEM.t() | DSMR.Telegram.MBus.t()]
        }

  defstruct header: nil, checksum: nil, data: []

  defmodule OBIS do
    @type t() :: %__MODULE__{
            code: String.t(),
            medium: atom(),
            channel: integer(),
            tags: [keyword()]
          }

    defstruct code: nil, medium: nil, channel: nil, tags: nil

    def new({:obis, [medium, channel | tags]}) do
      code = "#{medium}-#{channel}:#{Enum.join(tags, ".")}"

      medium = interpretet_medium(medium)
      tags = interpretet_tags(tags)

      %OBIS{code: code, medium: medium, channel: channel, tags: tags}
    end

    defp interpretet_medium(0), do: :abstract
    defp interpretet_medium(1), do: :electricity
    defp interpretet_medium(6), do: :heat
    defp interpretet_medium(7), do: :gas
    defp interpretet_medium(8), do: :water
    defp interpretet_medium(_), do: :unknown

    defp interpretet_tags([0, 2, 8]), do: [general: :version]
    defp interpretet_tags([1, 0, 0]), do: [general: :timestamp]
    defp interpretet_tags([96, 1, 1]), do: [general: :equipment_identifier]
    defp interpretet_tags([96, 14, 0]), do: [general: :tariff_indicator]
    defp interpretet_tags([1, 8, 1]), do: [energy: :total, direction: :consume, tariff: :low]
    defp interpretet_tags([1, 8, 2]), do: [energy: :total, direction: :consume, tariff: :normal]
    defp interpretet_tags([2, 8, 1]), do: [energy: :total, direction: :produce, tariff: :low]
    defp interpretet_tags([2, 8, 2]), do: [energy: :total, direction: :produce, tariff: :normal]
    defp interpretet_tags([1, 7, 0]), do: [power: :active, phase: :all, direction: :consume]
    defp interpretet_tags([2, 7, 0]), do: [power: :active, phase: :all, direction: :produce]
    defp interpretet_tags([21, 7, 0]), do: [power: :active, phase: :l1, direction: :consume]
    defp interpretet_tags([41, 7, 0]), do: [power: :active, phase: :l2, direction: :consume]
    defp interpretet_tags([61, 7, 0]), do: [power: :active, phase: :l3, direction: :consume]
    defp interpretet_tags([22, 7, 0]), do: [power: :active, phase: :l1, direction: :produce]
    defp interpretet_tags([42, 7, 0]), do: [power: :active, phase: :l2, direction: :produce]
    defp interpretet_tags([62, 7, 0]), do: [power: :active, phase: :l3, direction: :produce]
    defp interpretet_tags([31, 7, 0]), do: [amperage: :active, phase: :l1]
    defp interpretet_tags([51, 7, 0]), do: [amperage: :active, phase: :l2]
    defp interpretet_tags([71, 7, 0]), do: [amperage: :active, phase: :l3]
    defp interpretet_tags([32, 7, 0]), do: [voltage: :active, phase: :l1]
    defp interpretet_tags([52, 7, 0]), do: [voltage: :active, phase: :l2]
    defp interpretet_tags([72, 7, 0]), do: [voltage: :active, phase: :l3]
    defp interpretet_tags([96, 7, 9]), do: [power_failures: :long]
    defp interpretet_tags([96, 7, 21]), do: [power_failures: :short]
    defp interpretet_tags([99, 97, 0]), do: [power_failures: :event_log]
    defp interpretet_tags([32, 32, 0]), do: [voltage: :sags, phase: :l1]
    defp interpretet_tags([52, 32, 0]), do: [voltage: :sags, phase: :l2]
    defp interpretet_tags([72, 32, 0]), do: [voltage: :sags, phase: :l3]
    defp interpretet_tags([32, 36, 0]), do: [voltage: :swells, phase: :l1]
    defp interpretet_tags([52, 36, 0]), do: [voltage: :swells, phase: :l2]
    defp interpretet_tags([72, 36, 0]), do: [voltage: :swells, phase: :l3]
    defp interpretet_tags([96, 13, 0]), do: [message: :text]
    defp interpretet_tags([96, 13, 1]), do: [message: :code]
    defp interpretet_tags([24, 1, 0]), do: [mbus: :device_type]
    defp interpretet_tags([96, 1, 0]), do: [mbus: :equipment_identifier]
    defp interpretet_tags([24, 2, 1]), do: [mbus: :measurement]
    defp interpretet_tags(_), do: []
  end

  defmodule Value do
    @type t() :: %__MODULE__{
            value: integer() | float() | String.t(),
            raw: String.t(),
            unit: String.t()
          }

    defstruct value: nil, raw: nil, unit: nil

    def new({:value, [[{_type, value}, {:raw, raw}], unit: unit]}) do
      %Value{value: value, raw: raw, unit: unit}
    end

    def new({:value, [[{_type, value}, {:raw, raw}]]}) do
      %Value{value: value, raw: raw}
    end
  end

  defmodule COSEM do
    @type t() :: %__MODULE__{obis: OBIS.t(), values: [Value.t()]}

    defstruct obis: nil, values: []

    def new([obis | values]) do
      obis = OBIS.new(obis)
      values = Enum.map(values, &Value.new/1)

      %COSEM{obis: obis, values: values}
    end
  end

  defmodule MBus do
    @type t() :: %__MODULE__{channel: integer(), data: [DSMR.Telegram.COSEM.t()]}

    defstruct channel: nil, data: []

    def new(channel, cosem) do
      %MBus{channel: channel, data: [COSEM.new(cosem)]}
    end
  end

  defmodule Header do
    @type t() :: %__MODULE__{manufacturer: String.t(), model: String.t()}

    defstruct manufacturer: nil, model: nil

    def new([{:manufacturer, manufacturer}, {:model, model}]) do
      %Header{manufacturer: manufacturer, model: model}
    end
  end

  defmodule Checksum do
    @type t() :: %__MODULE__{value: String.t()}

    defstruct value: nil

    def new(checksum) do
      %Checksum{value: checksum}
    end
  end
end
