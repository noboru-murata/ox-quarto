#' talk-sample.org の下準備 (talk/preamble-piml.R の写し．データの場所だけ変えた)
#' 数値実験の結果は data/*.csv (talk のデータの一部) を読むだけで,
#' ここでは計算しない.
library(ggplot2)
library(dplyr)
library(tidyr)
library(readr)
library(patchwork)   # 図を並べる

#' 日本語表示の設定 (samples/org/preamble.R と同じ方針)
if (Sys.info()["sysname"] == "Darwin") {
    jp_font <- "HiraMaruProN-W4"   # quartz/AGG は PostScript 名
} else {
    jp_font <- "Noto Sans CJK JP"
}

#' 図の配色: スライドの palette (indigo / jade / dracula / lavender / burgundy) によらず使える一般的な色
#' 系列の色は Okabe–Ito の色覚多様性に配慮した配色から取り，背景は透明にして
#' 淡い背景の palette (indigo: #fafafa，jade: #F3F6F4 など) ならどれでも馴染むようにする．
#'   primary   青        主な結果 (提案手法・PINN)
#'   secondary 青緑      2 番目の系列 (円弧などの区間)
#'   alert     朱色      比較対象・失敗例・注意
#'   accent    赤紫      3 番目以降の系列
#'   ink / soft / gray / rule  文字・補助の文字・参照線・格子の灰色
piml_col <- c(ink = "#222222", soft = "#555555", gray = "#999999", rule = "#DDDDDD",
              primary = "#0072B2", secondary = "#009E73", alert = "#D55E00", accent = "#CC79A7",
              paper = "transparent")

#' 図の背景は透明 (スライドの背景色がそのまま見える)
knitr::opts_chunk$set(dev.args = list(bg = "transparent"))

theme_set(
    theme_minimal(base_size = 16, base_family = jp_font) +
    theme(plot.background  = element_rect(fill = NA, colour = NA),
          panel.grid.minor = element_blank(),
          panel.grid.major = element_line(colour = piml_col[["rule"]]),
          axis.title       = element_text(colour = piml_col[["soft"]]),
          axis.text        = element_text(colour = piml_col[["soft"]]),
          legend.position  = "top",
          legend.title     = element_blank())
)
update_geom_defaults("text",  list(family = jp_font))
update_geom_defaults("label", list(family = jp_font))

#' データ
data_dir <- "data"
read_piml <- function(name) read_csv(file.path(data_dir, name), show_col_types = FALSE)
