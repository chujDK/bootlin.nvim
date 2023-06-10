A simple telescope extension use the bootlin elixir REST api

## usage

### install

- lazy

```lua
lazy {
    'chujDK/bootlin.nvim'
    event = "VeryLazy",
}
```

### setup

currently the code is shity, you need setup environment variable to use it..

```bash
export NVIM_BOOTLIN_HOST='https://elixir.bootlin.com/' # set the host, you can change to your local server
export NVIM_BOOTLIN_REST_PROJECT=musl # set project's name
export NVIM_BOOTLIN_REST_PROJECT_DIR=/home/chuj/projects/c/musl/ # set local source dir
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
