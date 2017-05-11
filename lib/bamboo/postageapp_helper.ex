defmodule Bamboo.PostageAppHelper do
  @moduledoc """
  Functions for using features specific to PostageApp e.g. templates
  """

  alias Bamboo.Email

  @doc """
  Send emails using PostageApp's template API.

  PostageApp's API docs for this can be found [here](http://help.postageapp.com/kb/api/send_message).

  ## Example

    postageapp_template(email, "POSTAGEAPP_TEMPLATE"))
  """
  def postageapp_template(email, template_name) do
    Email.put_private(email, :postageapp_template, template_name)
  end

  @doc """
  Variables that can be used for content replacement within PostageApp's template

  ## Example
    postageapp_variables(%{variable_name: "value"})
  """
  def postageapp_variables(email, variables = %{}) do
    Email.put_private(email, :postageapp_variables, variables)
  end
end