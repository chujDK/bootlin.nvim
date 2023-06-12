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

so `bat` is needed for preview the code in the telescope window.

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


## example

I have always wanted to read the Linux source code without having to build it first and then use lsp to read it. I want to be able to simply type the version number and start reading whenever I want. So, I have created a shell script:

```bash
#!/usr/bin/env bash

project_dir=/home/chuj/projects/c/linux/
tag=`git -C $project_dir tag | tac | fzf --query 'v' --prompt "chose a tag:"`
git -C $project_dir checkout $tag

NVIM_BOOTLIN_HOST='http://172.17.0.2' \
  NVIM_BOOTLIN_REST_PROJECT=linux \
  NVIM_BOOTLIN_REST_PROJECT_DIR=$project_dir \
  NVIM_BOOTLIN_REST_TAG=$tag \
  NVIM_LSP_C_SUPPRESS=1 \
  NVIM_BOOTLIN_ENABLE=1 \
  BAT_THEME="Visual Studio Dark+" nvim -R -c ":cd $project_dir"
```

Save this as `bootlin_nvim_read_linux`.

Then bind `gd` and `gr` to search defs/refs.

Here goes the demo:

![bootlin-nvim-demo](https://github.com/chujDK/bootlin.nvim/assets/32593305/a92860a3-145a-4a42-a57c-15425e15f505)
