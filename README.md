A simple telescope extension use the bootlin elixir REST api

## usage

### install

- lazy

```lua
lazy {
    'chujDK/bootlin.nvim'
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope.nvim'
    },
    event = "VeryLazy",
}
```

### dependency

currently, the previewer is using [bat](https://github.com/sharkdp/bat) to provide syntax highlighting and line highlighting

```lua
    ...
    return { "bat", "--line-range", start .. ":" .. finish, "--highlight-line", lnum, file_path }
```

so this is needed for preview the code in the telescope window.

needless to say, [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) is needed too.

### setup

currently the code is shity, you need setup environment variable to use it..

take `musl` project as an example.

```bash
export NVIM_BOOTLIN_HOST='https://elixir.bootlin.com/' # set the host, you can change to your local server
export NVIM_BOOTLIN_REST_PROJECT=musl # set project's name
export NVIM_BOOTLIN_REST_PROJECT_DIR=/path/to/musl/project/you/cloned # set local source dir
export NVIM_BOOTLIN_REST_TAG=v1.2.4 # set project's version
export NVIM_BOOTLIN_ENABLE=1 # enable the plugin
```

### use

search references of `<ident>`

```vim
:lua require('telescope').extensions.bootlin.bootlinElixirReferences('<ident>')
```

search  of `<ident>`

```vim
:lua require('telescope').extensions.bootlin.bootlinElixirDefinitions('<ident>')
```
