defmodule Mix.Tasks.Salad.Setup do
  @moduledoc """
  Set up SaladUI in a Phoenix LiveView project.

  This task configures the complete SaladUI development environment by:

  * Adding TwMerge.Cache to the application supervision tree
  * Configuring CSS color scheme variables (default: gray)
  * Copying SaladUI CSS files to assets/css/
  * Patching Tailwind CSS configuration with SaladUI-specific settings
  * Installing tailwindcss-animate plugin
  * Setting up JavaScript imports and LiveView hooks

  ## Usage

      mix salad.setup
      mix salad.setup --color-scheme slate
      mix salad.setup -c blue

  ## Options

    * `--color-scheme` (or `-c`) - Color scheme to use (default: "gray")
      Available schemes: gray, slate, stone, neutral, red, orange, amber,
      yellow, lime, green, emerald, teal, cyan, sky, blue, indigo, violet,
      purple, fuchsia, pink, rose

  ## What it does

  1. **TwMerge Integration** - Adds TwMerge.Cache as a supervised process for
     CSS class merging functionality

  2. **CSS Setup**
     - Copies salad_ui.css to assets/css/
     - Adds color scheme variables to app.css
     - Imports SaladUI styles into the main CSS file

  3. **Tailwind Configuration**
     - Patches tailwind.config.js with SaladUI-specific plugins
     - Copies tailwind.colors.json with design tokens
     - Adds @tailwindcss/typography and tailwindcss-animate plugins

  4. **JavaScript Setup**
     - Downloads and installs tailwindcss-animate
     - Patches app.js to import SaladUI components and hooks
     - Registers SaladUIHook with LiveView

  ## After running this task

  You can immediately start using SaladUI components in your templates:

      <.button>Click me</.button>
      <.dialog id="my-dialog">
        <.dialog_content>
          <p>Hello world!</p>
        </.dialog_content>
      </.dialog>

  ## Files modified

  * `lib/[app]/application.ex` - Adds TwMerge.Cache
  * `assets/css/app.css` - Adds color scheme and imports
  * `assets/css/salad_ui.css` - Created
  * `assets/tailwind.config.js` - Updated with plugins and content paths
  * `assets/tailwind.colors.json` - Created
  * `assets/js/app.js` - Adds SaladUI imports and hooks
  * `assets/vendor/tailwindcss-animate.js` - Downloaded

  ## Example

      # Use default gray color scheme
      mix salad.setup

      # Use slate color scheme
      mix salad.setup --color-scheme slate

      # Short form
      mix salad.setup -c blue
  """
  use Igniter.Mix.Task

  @impl Igniter.Mix.Task
  def igniter(igniter) do
    {opts, _args} =
      OptionParser.parse!(igniter.args.argv,
        strict: [color_scheme: :string],
        aliases: [c: :color_scheme]
      )

    color_scheme = opts[:color_scheme] || "gray"

    igniter
    |> patch_tw_merge()
    |> patch_css_color_scheme(color_scheme)
    |> copy_salad_ui_css()
    |> patch_css_import_salad_ui()
    |> patch_tailwind_config()
    |> copy_tailwind_colors()
    |> install_tailwind_animate()
    |> patch_app_js()
  end

  defp patch_tw_merge(igniter) do
    Igniter.Project.Application.add_new_child(igniter, TwMerge.Cache)
  end

  defp patch_css_color_scheme(igniter, color_scheme) do
    css_file = "./assets/css/app.css"
    content = File.read!(css_file)

    IO.puts("Patching #{css_file}")

    color_scheme_code = "colors/#{color_scheme}.css" |> assets_path() |> File.read!()

    new_base_layer = """
    @layer base {
      #{color_scheme_code}
      * {
        @apply border-border !important;
      }
    }\n
    """

    File.write!(css_file, content <> "\n\n" <> new_base_layer)
    igniter
  end

  defp copy_salad_ui_css(igniter) do
    source_file = assets_path("salad_ui.css")
    target_file = "./assets/css/salad_ui.css"

    Igniter.copy_template(igniter, source_file, target_file, [])
  end

  defp patch_css_import_salad_ui(igniter) do
    css_file = "./assets/css/app.css"
    content = File.read!(css_file)
    import_snippet = "@import \"./salad_ui.css\";\n"

    IO.puts("Patching #{css_file}")
    IO.puts("Add:  #{import_snippet}")

    unless String.contains?(content, import_snippet) do
      import_regex = ~r/(@import.*?;\n)/
      imports = Regex.scan(import_regex, content)

      updated_content =
        case imports do
          [] ->
            # No imports found, return original content
            import_snippet <> "\n" <> content

          _ ->
            # Get the last import statement
            last_import = imports |> List.last() |> List.first()

            # Replace only the last occurrence
            # First, split the string at the last import
            [before_last_import, after_last_import] = String.split(content, last_import, parts: 2)

            # Reconstruct the string with the inserted content after the last import
            before_last_import <> last_import <> import_snippet <> after_last_import
        end

      File.write(css_file, updated_content)
    end

    igniter
  end

  defp copy_tailwind_colors(igniter) do
    source_file = assets_path("tailwind.colors.json")
    target_file = "./assets/tailwind.colors.json"

    Igniter.copy_template(igniter, source_file, target_file, [])
  end

  defp patch_tailwind_config(igniter) do
    tailwind_config_path = "./assets/tailwind.config.js"
    SaladUI.Patcher.TailwindPatcher.patch(tailwind_config_path)

    igniter
  end

  @default_tailwind_animate_version "1.0.7"

  defp install_tailwind_animate(igniter) do
    tag = @default_tailwind_animate_version

    Mix.shell().info("Downloading tailwindcss-animate.js v#{tag}")

    url = "https://raw.githubusercontent.com/jamiebuilds/tailwindcss-animate/refs/tags/v#{tag}/index.js"
    output_path = "assets/vendor/tailwindcss-animate.js"

    :inets.start()
    :ssl.start()

    case :httpc.request(:get, {url, []}, [], body_format: :binary) do
      {:ok, {{_version, 200, _reason_phrase}, _headers, body}} ->
        # Write the body to file
        File.write!(output_path, body)
        :ok

      {:ok, {{_version, status_code, _reason_phrase}, _headers, _body}} ->
        {:error, "Failed to download tailwindcss-animate with status #{status_code}"}

      {:error, reason} ->
        {:error, "Failed to download tailwindcss-animate.js: #{inspect(reason)}"}
    end

    igniter
  end

  defp assets_path(directory) do
    Path.join([:code.priv_dir(:salad_ui), "static/assets", directory])
  end

  # Patch app.js to import library JavaScript
  @js_import """
  import SaladUI from "salad_ui";
  import "salad_ui/components/dialog";
  import "salad_ui/components/select";
  import "salad_ui/components/tabs";
  import "salad_ui/components/radio_group";
  import "salad_ui/components/popover";
  import "salad_ui/components/hover-card";
  import "salad_ui/components/collapsible";
  import "salad_ui/components/tooltip";
  import "salad_ui/components/accordion";
  import "salad_ui/components/slider";
  import "salad_ui/components/switch";
  import "salad_ui/components/dropdown_menu";
  """
  @js_hooks "SaladUI: SaladUI.SaladUIHook"
  defp patch_app_js(igniter) do
    app_js_path = "./assets/js/app.js"

    js_content =
      app_js_path
      |> File.read!()
      |> SaladUI.Patcher.JSPatcher.patch_js(@js_import, @js_hooks)

    File.write!(app_js_path, js_content)

    igniter
  end
end
