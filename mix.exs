defmodule BambooPostageapp.Mixfile do
  use Mix.Project

  @project_url "https://github.com/GBH/bamboo_postageapp"

  def project do
    [
      app:              :bamboo_postageapp,
      version:          "0.0.1",
      elixir:           "~> 1.2",
      source_url:       @project_url,
      homepage_url:     @project_url,
      name:             "Bamboo PostageApp Adapter",
      description:      "A Bamboo adapter for PostageApp",
      build_embedded:   Mix.env == :prod,
      start_permanent:  Mix.env == :prod,
      package:          package(),
      deps:             deps()
    ]
  end

  def application do
    [extra_applications: [:logger, :hackney]]
  end

  defp deps do
    [
      {:bamboo,   "~> 0.5"},
      {:hackney,  "~> 1.6"},
      {:poison,   ">= 1.5.0"},
      {:plug,     "~> 1.0"},
      {:cowboy,   "~> 1.0", only: [:test, :dev]},
      {:ex_doc,   "~> 0.13", only: :dev}
    ]
  end

  defp package do
    [
      maintainers:  ["Oleg Khabarov"],
      licenses:     ["MIT"],
      links:        %{"GitHub" => @project_url}
    ]
  end
end
