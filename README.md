# laravel-tools.nvim

A wrapper around laravel's artisan command.

## INTRODUCTION

This plugin is a collection of a few artisan scripts that I have built over the time, which has helped me make my life
a bit easier.

At it's core it is just a wrapper around `php artisan`, apart from a few specialized commands, that help in navigating
the codebase, and quick scratch work.

You can find more help by running `h artisan.txt`

## INSTALLATION
You should be able to install this plugin using any plugin manager of your choice.

(If some plugin manager does not work then feel free to open an issue).

### vim.pack
```lua
vim.pack.add {
    "https://github.com/tomshoo/laravel-tools.nvim",
}
```

### lazy.vim
```lua
{
    "tomshoo/laravel-tools.nvim",
}
```

### vim-plug
```vim
Plug 'tomshoo/laravel-tools.nvim'
```

## CONTRIBUTING

This plugin is a fully handcrafted product. I do not like to use AI, but if you have something that you might want in
this plugin then you can craft a PR even with AI. Just make sure that your code is thoroughly reviewed by you, and any
code written by AI is properly disclosed.

## INSPIRATION
- [vim-fugitive](https://github.com/tpope/vim-fugitive) I really love how seamlessly fugitive works, and wanted something similar in for Laravel.
