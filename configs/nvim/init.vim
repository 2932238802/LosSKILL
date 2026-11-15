call plug#begin('~/.vim/plugged')

" Essential plugins
Plug 'tpope/vim-sensible'
Plug 'jiangmiao/auto-pairs'
Plug 'scrooloose/nerdtree'
Plug 'majutsushi/tagbar'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'itchyny/lightline.vim'
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'
Plug 'dyng/ctrlpvim'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'preservim/nerdcommenter'
Plug 'jiangmiao/omnipopup'

" Language support
Plug 'digitaltoad/vim-pug'
Plug 'pangloss/vim-javascript'
Plug 'mxw/vim-jsx'
Plug 'posva/vim-vue'
Plug 'jparise/vim-graphql'
Plug 'leafgarland/typescript-vim'
Plug 'maxmellon/vim-jsx-pretty'
Plug 'styled-components/vim-styled-components'
Plug 'othree/html5.vim'
Plug 'hail2u/vim-css3-syntax'
Plug 'cakebaker/scss-syntax'
Plug 'groenewege/vim-less'

call plug#end()

" Basic settings
set number
set relativenumber
set tabstop=4
set shiftwidth=4
set expandtab
set autoindent
set smartindent
set fileencodings=utf-8,gbk,gb2312,cp936
set termencoding=utf-8
set encoding=utf-8
syntax enable
colorscheme desert

" NERDTree settings
map <C-n> :NERDTreeToggle<CR>

" Airline settings
let g:airline_theme='tomorrow'
let g:airline#extensions#tabline#enabled = 1

" GitGutter settings
let g:gitgutter_sign_added = '+'
let g:gitgutter_sign_modified = '~'
let g:gitgutter_sign_removed = '-'

" CtrlP settings
let g:ctrlp_custom_ignore = 'node_modules\|dist\|build'
let g:ctrlp_map = '<c-p>'

" Leader key
let mapleader = ","
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>x :x<CR>
nnoremap <leader>s :wq<CR>
nnoremap <leader>v :vsplit<CR>
nnoremap <leader>h :split<CR>

" Folding
set foldmethod=indent
set foldlevel=99

" Search settings
set hlsearch
set incsearch
set ignorecase
set smartcase
