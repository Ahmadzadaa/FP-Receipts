# =============================================================================
# FP RECEIPTS — İNTERAKTİV ANALİTİKA STUDİYASI
# Bütün R kodu, CSS dizaynı və JavaScript bu bir faylın daxilindədir.
# =============================================================================
# İşə salmaq (R >= 4.1):
#   1. Bu faylı fp_receipts.rds və fp_map.rds ilə eyni qovluğa yerləşdirin.
#   2. RStudio-da faylı açın və Source düyməsinə basın.
#      Alternativ: terminalda Rscript FP_Receipts_Shiny.R
#   3. Tətbiq brauzerdə açılır. Dayandırmaq: RStudio Stop və ya Ctrl+C.
#
# İlk istifadədən əvvəl paketlər:
# install.packages(c("shiny", "bslib", "plotly", "DT", "data.table",
#                    "stringr", "stringi", "htmltools", "jsonlite", "digest"))
#
# Məlumat başqa qovluqdadırsa, Source-dan əvvəl:
# Sys.setenv(FP_RECEIPTS_DATA_DIR = "/tam/yol/melumat_qovlugu")
#
# Mənbə RDS faylları yalnız oxunur; üzərlərinə yazılmır.
# İlk açılış 10 milyon sətrin hazırlanmasına görə bir qədər uzun çəkə bilər.
# Sürətli növbəti açılış üçün istifadəçinin R keş qovluğunda keş yaradılır.
# Əlavə R, CSS, JS, HTML və ya layihə faylı tələb olunmur.
#
# Bölmələr: İcmal; Satış strukturu; POS və məhsullar; Anomaliyalar;
# Proqnoz və fərziyyələr; Ssenari laboratoriyası; Məlumat; Metodologiya.
# =============================================================================

.fp_required <- c('shiny', 'bslib', 'plotly', 'DT', 'data.table', 'stringr',
                  'stringi', 'htmltools', 'jsonlite', 'digest')
.fp_missing <- .fp_required[!vapply(.fp_required, requireNamespace, logical(1), quietly = TRUE)]
if (length(.fp_missing)) {
  stop('Çatışmayan paketlər: ', paste(.fp_missing, collapse = ', '),
       '\nƏvvəlcə bu əmri işlədin:\ninstall.packages(c(',
       paste(sprintf('"%s"', .fp_missing), collapse = ', '), '))', call. = FALSE)
}
library(shiny)
library(DT)
library(plotly)
library(data.table)
.fp_cores <- parallel::detectCores()
setDTthreads(if (is.na(.fp_cores)) 1L else min(2L, .fp_cores))
options(shiny.maxRequestSize = 20 * 1024^2, shiny.sanitize.errors = TRUE)

# Faylın yeri source() və Rscript ilə avtomatik müəyyən olunur.
.fp_script_dir <- local({
  paths <- vapply(sys.frames(), function(frame) {
    path <- frame$ofile
    if (is.character(path) && length(path) == 1L) path else ''
  }, character(1))
  paths <- paths[nzchar(paths)]
  if (length(paths)) {
    dirname(normalizePath(tail(paths, 1L), mustWork = FALSE))
  } else {
    args <- commandArgs(trailingOnly = FALSE)
    arg <- args[startsWith(args, '--file=')]
    if (length(arg)) dirname(normalizePath(sub('^--file=', '', arg[1]), mustWork = FALSE)) else getwd()
  }
})
.fp_data_dir <- local({
  requested <- Sys.getenv('FP_RECEIPTS_DATA_DIR', unset = '')
  candidates <- if (nzchar(requested)) requested else unique(c(.fp_script_dir, getwd(), dirname(.fp_script_dir)))
  found <- vapply(candidates, function(path) {
    all(file.exists(file.path(path, c('fp_receipts.rds', 'fp_map.rds'))))
  }, logical(1))
  if (!any(found)) {
    stop('fp_receipts.rds və fp_map.rds tapılmadı. Bu .R faylını hər iki RDS ilə eyni qovluğa qoyun ',
         'və ya Sys.setenv(FP_RECEIPTS_DATA_DIR = "/tam/yol") təyin edin.', call. = FALSE)
  }
  normalizePath(candidates[which(found)[1]], mustWork = TRUE)
})

# ── DAXİLİ DİZAYN VƏ BRAUZER FUNKSİYALARI ─────────────────────────────────

.fp_css <- r"----(:root{--navy:#102d40;--navy2:#1c3f52;--accent:#0b7666;--mint:#b9eadb;--ink:#1a3040;--muted:#71828f;--paper:#f3f5f7;--card:#fff;--stroke:#e3e9ed;--warning:#b66b15;--red:#bf4e43;--shadow:0 4px 22px #12324805}*{box-sizing:border-box}body{font-family:system-ui,-apple-system,'Segoe UI',sans-serif;background:var(--paper);color:var(--ink);font-size:14px;margin:0}body>.container-fluid{padding:0}.app-shell{display:flex;min-height:100vh}.rail{width:232px;position:fixed;inset:0 auto 0 0;background:var(--navy);color:#e0ecef;padding:32px 18px 20px;display:flex;flex-direction:column;z-index:40}.brand{display:flex;gap:12px;align-items:center;margin:0 12px 38px}.brand-mark{display:grid;place-items:center;background:#b9eadb;color:#153b35;width:44px;height:44px;border-radius:12px;font-weight:850;font-size:21px;letter-spacing:-1px}.brand strong{display:block;font-size:23px;letter-spacing:-.7px;line-height:1.2}.brand small{display:block;color:#7ea2b3;font-size:8px;letter-spacing:1.8px;margin-top:6px}.rail-caption{font-size:9px;letter-spacing:1.6px;color:#7294a6;margin:23px 15px 12px}.rail-link.btn{display:flex;align-items:center;text-align:left;gap:12px;width:100%;color:#adc5cf;border:0;border-radius:8px;background:transparent;padding:12px 14px;font-size:12px;font-weight:550;box-shadow:none;margin:2px 0;white-space:normal}.rail-link .fa{width:17px;font-size:14px}.rail-link:hover{background:#ffffff0c;color:#fff}.rail-link.active{background:#b9eadb;color:#153b35;font-weight:700}.rail-bottom{margin-top:auto;padding:28px 14px 0;font-size:10px;color:#91adba}.rail-bottom strong{display:block;color:#e1eff4;margin:10px 0 6px;font-size:11px}.rail-bottom p{font-size:10px;color:#7297a8}.status-dot{display:inline-block;width:6px;height:6px;border-radius:50%;background:#6ed8ad;margin-right:7px}.help-button.btn{font-size:10px;padding:12px 0 0;color:#aec7d1;border:0;background:none}.main{margin-left:232px;width:calc(100% - 232px);padding:0 36px}.topbar{height:78px;display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid var(--stroke)}.breadcrumb{display:flex;align-items:center;gap:14px;color:var(--muted);margin:0;font-size:11px}.breadcrumb>span:first-of-type{color:var(--ink);font-weight:700}.slash{color:#bac4cb}.top-actions{display:flex;gap:14px;align-items:center}.top-actions .form-group{margin:0;font-size:11px}.top-actions .checkbox{margin:0}.btn-quiet{background:transparent;border:0;color:var(--muted);font-size:11px;font-weight:600;padding:8px 4px;box-shadow:none}.btn-quiet:hover{color:var(--accent);background:transparent}.filter-shell{background:var(--card);border:1px solid var(--stroke);border-radius:12px;padding:17px 21px 0;margin-top:24px;box-shadow:var(--shadow)}.filter-top{display:flex;align-items:center;gap:18px;font-size:11px;margin-bottom:12px}.filter-top strong{color:var(--ink);font-size:12px}.filter-top .btn{margin-left:auto}.filter-meta{font-size:10px;color:var(--muted)}.filter-grid{display:grid;grid-template-columns:1.3fr 1.2fr 1.1fr auto;gap:18px;align-items:start}.control-label{font-size:10px;font-weight:650;letter-spacing:.15px;margin-bottom:7px;color:var(--muted)}.form-control,.selectize-input{font-size:12px!important;border:1px solid var(--stroke)!important;border-radius:7px!important;box-shadow:none!important;background:var(--card)!important;color:var(--ink)!important;min-height:37px}.selectize-control.multi .selectize-input>div{background:#e4f3ed;color:#225947;font-size:10px}.selectize-dropdown{font-size:12px}.input-daterange input{padding:7px 4px}.input-group-addon{background:var(--paper);border-color:var(--stroke);font-size:10px}.btn-apply{margin-top:25px;border:0;border-radius:7px;background:var(--accent);color:white;font-size:12px;font-weight:650;padding:10px 17px}.btn-apply:hover,.btn-apply:focus{background:#075d50;color:white}.advanced{border-top:1px solid var(--stroke);margin:2px -21px 0;padding:11px 21px}.advanced>summary{cursor:pointer;color:var(--muted);font-size:10px;font-weight:600;list-style:none}.advanced>summary:after{content:'＋';float:right}.advanced[open]>summary:after{content:'−'}.advanced-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:6px 20px;margin-top:16px}.check-row{display:flex;flex-wrap:wrap;gap:18px}.check-row .form-group{margin-bottom:4px;font-size:11px}.microcopy{color:var(--muted);font-size:10px;line-height:1.65;margin:8px 0}.page-intro{display:flex;justify-content:space-between;align-items:center;gap:16px;margin:30px 0 24px}.eyebrow{font-size:9px;font-weight:750;letter-spacing:1.8px;color:var(--accent);margin-bottom:9px}.page-intro h1{font-size:27px;font-weight:720;letter-spacing:-1px;line-height:1.25;margin:0 0 9px}.page-intro p{color:var(--muted);font-size:11px;line-height:1.7;margin:0;max-width:760px}.btn-outline{border:1px solid var(--stroke);border-radius:7px;background:var(--card);color:var(--ink);font-size:11px;font-weight:650;padding:10px 14px;white-space:nowrap}.btn-outline:hover{border-color:var(--accent);color:var(--accent);background:var(--card)}.kpi-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:16px;margin-bottom:22px}.kpi{border:1px solid var(--stroke);border-radius:11px;background:var(--card);padding:20px 23px;min-height:132px;box-shadow:var(--shadow)}.kpi.featured{background:var(--navy);border-color:var(--navy);color:#fff}.kpi-label{font-size:10px;font-weight:550;color:var(--muted);display:flex;align-items:center;justify-content:space-between}.kpi.featured .kpi-label{color:#94b1bd}.kpi-label .fa{color:#98b6be}.kpi-value{font-size:31px;font-weight:730;letter-spacing:-1px;margin-top:13px;line-height:1.1}.kpi-sub{color:var(--muted);font-size:9px;line-height:1.6;margin-top:12px}.kpi.featured .kpi-sub{color:#9bc4c1}.two-col{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:22px;margin-bottom:22px}.wide-left{grid-template-columns:minmax(0,1.85fr) minmax(270px,1fr)}.chart-card{background:var(--card);border:1px solid var(--stroke);border-radius:11px;padding:23px 24px 16px;box-shadow:var(--shadow);min-width:0;margin-bottom:22px}.two-col>.chart-card{margin-bottom:0}.card-heading h3{font-size:13px;font-weight:700;margin:0 0 7px;letter-spacing:-.1px}.card-heading p{font-size:10px;color:var(--muted);line-height:1.65;margin:0 0 14px}.inline-controls{display:flex;gap:18px;flex-wrap:wrap;font-size:10px;align-items:center}.inline-controls .form-group{flex:1;margin-bottom:5px}.inline-controls .radio-inline{margin-right:10px}.insight{padding:17px 0;border-bottom:1px solid var(--stroke)}.insight:last-child{border-bottom:0}.insight span{font-size:10px;color:var(--muted);display:block}.insight strong{font-size:20px;letter-spacing:-.5px;display:block;margin:5px 0;color:var(--ink)}.insight p{font-size:11px;line-height:1.6;color:var(--muted);margin:4px 0}.insight .accent{color:var(--accent)}.notice{background:#f9edda;border:1px solid #eddbbd;border-radius:8px;color:#81561f;padding:12px 16px;font-size:11px;line-height:1.7;margin:20px 0 0}.notice.info{background:#e6f3ef;color:#316b5b;border-color:#cfe5dc}.notice:empty{display:none}.empty{padding:48px 20px;text-align:center;color:var(--muted);font-size:13px}.local-controls{display:flex;gap:25px;background:var(--card);padding:17px 22px;border:1px solid var(--stroke);border-radius:9px;margin-bottom:22px;align-items:center;flex-wrap:wrap}.local-controls .form-group{margin:0;min-width:120px;flex:1}.local-controls .form-group:first-child{flex:1.25}.local-controls .checkbox{font-size:11px}.local-controls .radio-inline{font-size:11px}.local-controls .shiny-input-container{width:auto}.local-controls input[type=number]{max-width:120px}.method-list dt{font-size:12px;margin-top:20px;margin-bottom:9px}.method-list dd{font-size:12px;color:var(--muted);line-height:1.85;margin-left:0}.method-list dt:first-child{margin-top:12px}.app-footer{border-top:1px solid var(--stroke);margin:32px 0 0;padding:20px 0;display:flex;justify-content:space-between;color:var(--muted);font-size:9px}.scenario-layout{grid-template-columns:minmax(260px,.8fr) minmax(0,1.5fr)}#scenario_kpi{display:grid;grid-template-columns:1fr 1fr;gap:14px}#scenario_kpi .kpi{box-shadow:none;padding:16px;min-height:118px}#scenario_kpi .kpi-value{font-size:27px}.dataTables_wrapper{font-size:11px;margin-top:16px}.dataTables_wrapper table.dataTable thead th{font-size:10px;background:var(--paper);color:var(--muted);padding:13px 10px;border-bottom:1px solid var(--stroke)}table.dataTable tbody td{padding:11px 10px!important;border-color:var(--stroke)!important;color:var(--ink);vertical-align:middle}table.dataTable tbody tr{background:var(--card)}table.dataTable tbody tr.selected{background:#dcf0e8!important}table.dataTable.hover tbody tr:hover{background:#edf5f2!important}table.dataTable{border-bottom:1px solid var(--stroke)!important}.dataTables_filter input{border:1px solid var(--stroke);border-radius:6px;padding:5px;background:var(--card);color:var(--ink)}.dt-buttons button{font-size:10px}.table-scroll{overflow:auto}.source-grid{display:grid;grid-template-columns:1fr 1fr;gap:20px;font-size:11px;line-height:1.9;color:var(--muted)}.source-grid code{font-size:9px;word-break:break-all;color:var(--accent)}.shiny-output-error-validation{color:var(--muted)!important;padding:36px 12px;font-size:12px}.shiny-busy .btn-apply{opacity:.65}.recalculating{opacity:.4!important;transition:opacity .2s}.mobile-menu{display:none;background:none;border:0}.modal-content{border:0;border-radius:14px;background:var(--card);color:var(--ink)}.modal-header{border-color:var(--stroke)}.modal-body{font-size:12px;line-height:1.8}.modal-title{font-size:18px}.toast-container{z-index:10000}.irs--shiny .irs-bar,.irs--shiny .irs-single{background:var(--accent);border-color:var(--accent)}.irs--shiny .irs-handle{border-color:var(--accent)}.irs--shiny .irs-single:before{border-top-color:var(--accent)}.irs-grid-text{font-size:9px}a{color:var(--accent)}:focus-visible{outline:2px solid #46b59a!important;outline-offset:3px}.tab-content>.tab-pane{padding:0}.shiny-notification{border-radius:8px;font-size:12px}.check-row input,.top-actions input{accent-color:var(--accent)}body.dark{--paper:#10212e;--card:#172c3a;--ink:#e6eff4;--muted:#94aab7;--stroke:#294050;--navy:#0b1923;--accent:#7cd9bf;--shadow:none}.dark .btn-apply{background:#207f6d;color:#fff}.dark .notice{background:#423923;border-color:#655236;color:#ead6ae}.dark .notice.info{background:#153e34;border-color:#24594a;color:#adddca}.dark .selectize-dropdown,.dark .dataTables_wrapper .dataTables_paginate .paginate_button{background:var(--card);color:var(--ink)!important}.dark .selectize-dropdown .active{background:#264a40;color:#fff}.dark .form-select{background-color:var(--card);color:var(--ink);border-color:var(--stroke)}.dark table.dataTable.hover tbody tr:hover{background:#204337!important}.dark .kpi.featured{background:#1b4b43;border-color:#2d695a}.dark .btn-outline{color:var(--ink)}.dark .selectize-input input{color:var(--ink)!important}@media(min-width:1600px){.main{padding:0 48px}.page-intro h1{font-size:32px}.kpi-value{font-size:37px}.chart-card{padding:27px 28px}.filter-grid{grid-template-columns:1.1fr 1.15fr 1.1fr auto}}@media(max-width:1150px){.rail{width:204px;padding:25px 12px}.main{margin-left:204px;width:calc(100% - 204px);padding:0 24px}.filter-grid{grid-template-columns:1fr 1fr}.btn-apply{margin-top:24px}.kpi-grid{grid-template-columns:repeat(2,1fr)}.two-col,.wide-left{grid-template-columns:1fr}.brand{margin-left:5px}.brand strong{font-size:21px}.page-intro h1{font-size:25px}.top-actions .btn{font-size:10px}.scenario-layout{grid-template-columns:1fr}}@media(max-width:760px){.rail{transform:translateX(-100%);width:230px;transition:transform .2s}.menu-open .rail{transform:translateX(0)}.main{margin-left:0;width:100%;padding:0 16px}.mobile-menu{display:block;color:var(--ink);font-size:18px}.topbar{height:65px}.top-actions .btn{display:none}.filter-shell{margin-top:15px;padding:14px 15px 0}.filter-grid{gap:8px 12px}.filter-top{gap:6px;flex-wrap:wrap}.filter-meta{font-size:9px}.advanced{margin:0 -15px;padding:11px 15px}.advanced-grid{grid-template-columns:1fr 1fr;gap:8px}.page-intro{margin:24px 0 20px;align-items:flex-start;flex-direction:column}.page-intro h1{font-size:25px}.kpi-grid{gap:10px}.kpi{padding:17px;min-height:120px}.kpi-value{font-size:27px}.chart-card{padding:19px 16px}.local-controls{gap:15px;padding:15px}.source-grid{grid-template-columns:1fr}.app-footer{gap:12px}.breadcrumb{gap:9px}.top-actions{gap:0}.check-row{gap:4px 15px}.filter-top .btn{padding:0}.two-col{gap:15px;margin-bottom:15px}}@media print{.rail,.topbar,.filter-shell,.local-controls,.btn{display:none!important}.main{margin:0;width:100%;padding:0}.chart-card,.kpi{break-inside:avoid}.tab-pane.active{display:block!important}}
.shiny-input-container:not(.shiny-input-container-inline){width:100%;min-width:0}.rail{overflow-y:auto}.filter-grid{grid-template-columns:minmax(0,1.3fr) minmax(0,1.2fr) minmax(0,1.1fr) auto}.filter-grid>.form-group{min-width:0}.filter-grid .selectize-control{max-width:100%}.filter-grid .btn-apply{white-space:nowrap}.selectize-dropdown-content{max-height:250px}@media(max-width:1150px){.filter-grid{grid-template-columns:minmax(0,1fr) minmax(0,1fr)}}
#busy_state{display:none;color:var(--accent);font-size:10px;white-space:nowrap}.shiny-busy #busy_state{display:inline-flex;gap:7px;align-items:center}.draft-notice{font-size:10px;color:var(--warning);margin:11px 2px -9px}.dataTables_scrollBody>table.dataTable>thead>tr>th{padding-top:0!important;padding-bottom:0!important;border-top:0!important;border-bottom:0!important;height:0!important}.dataTables_scrollBody>table.dataTable>thead>tr>th .dataTables_sizing{height:0!important;overflow:hidden!important}
html,body{max-width:100%;overflow-x:hidden}.local-controls .shiny-input-container{max-width:100%}.chart-card .dataTables_wrapper{max-width:100%}@media(max-width:760px){.filter-grid>#dates,.filter-grid>.form-group:nth-child(2){grid-column:1 / -1}.rail .rail-link{flex-shrink:0}.rail .brand,.rail .rail-caption,.rail .rail-bottom{flex-shrink:0}.top-actions{max-width:42%}.breadcrumb{min-width:0;font-size:10px}.breadcrumb .shiny-text-output{white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:122px}}
.top-actions .shiny-input-container{width:auto;flex:0 0 auto}.top-actions .btn{white-space:nowrap;flex-shrink:0}.top-actions{flex-shrink:0}.rail-link.btn{font-size:11px}
)----"

.fp_js <- r"----((function(){
 const labels={overview:'İcmal',structure:'Satış strukturu',entities:'POS və məhsullar',quality:'Anomaliyalar',forecast:'Proqnoz və fərziyyələr',scenario:'Ssenari laboratoriyası',explorer:'Məlumat araşdırıcısı',method:'Metodologiya'};
 document.addEventListener('click',function(e){const el=e.target.closest('[data-view]');if(el){document.querySelectorAll('.rail-link').forEach(x=>x.classList.toggle('active',x===el));document.body.classList.remove('menu-open');window.scrollTo({top:0,behavior:'smooth'});}if(e.target.closest('#mobile-menu'))document.body.classList.toggle('menu-open');});
 document.addEventListener('keydown',e=>{if(e.key==='Escape')document.body.classList.remove('menu-open');if((e.ctrlKey||e.metaKey)&&e.key==='Enter'&&!e.repeat){const b=document.getElementById('apply');if(b)b.click();}});
 function setup(){if(!window.Shiny)return;Shiny.addCustomMessageHandler('fp_theme',function(dark){document.body.classList.toggle('dark',dark);try{localStorage.setItem('fp-theme',dark?'dark':'light')}catch(e){}setTimeout(()=>window.dispatchEvent(new Event('resize')),50)});
 Shiny.addCustomMessageHandler('fp_save_view',function(state){try{localStorage.setItem('fp-view-v1',JSON.stringify(state));Shiny.setInputValue('view_storage_result',{ok:true,time:Date.now()},{priority:'event'})}catch(e){Shiny.setInputValue('view_storage_result',{ok:false,time:Date.now()},{priority:'event'})}});
 Shiny.addCustomMessageHandler('fp_restore_view',function(message){try{const state=JSON.parse(localStorage.getItem('fp-view-v1')||'null');Shiny.setInputValue('restore_payload',{state:state,time:Date.now()},{priority:'event'})}catch(e){Shiny.setInputValue('restore_payload',{state:null,time:Date.now()},{priority:'event'})}});
 Shiny.addCustomMessageHandler('fp_nav',function(view){document.querySelectorAll('.rail-link').forEach(x=>x.classList.toggle('active',x.dataset.view===view));window.scrollTo({top:0,behavior:'smooth'})});
 }
 document.addEventListener('DOMContentLoaded',setup);
 $(document).on('shiny:connected',function(){try{const dark=localStorage.getItem('fp-theme')==='dark';if(dark){document.body.classList.add('dark');Shiny.setInputValue('dark',true,{priority:'event'});const el=document.getElementById('dark');if(el)el.checked=true;}}catch(e){}});
})();
)----"

# ── MƏLUMATIN HAZIRLANMASI ────────────────────────────────────────────────

# Original RDS files are read only. Cache holds compact dictionaries and numeric columns.
repair_encoding <- function(x) {
  bad <- !is.na(x) & grepl('[ÃÉÂÄÅ]', x)
  y <- iconv(x[bad], from='UTF-8', to='latin1'); Encoding(y) <- 'UTF-8'
  good <- !is.na(y) & validUTF8(y); x[which(bad)[good]] <- y[good]; x
}
product_key <- function(x) stringr::str_squish(toupper(repair_encoding(x)))
pos_key <- function(x) stringr::str_squish(gsub('[^A-Z0-9 ]', ' ', chartr('ƏĞİŞÇÖÜ?', 'EGISCOUE', toupper(x))))
GENERIC_POS <- c('MAGAZA','MARKET','APTEK','ANBAR','ERZAQ MAGAZASI','QARISIQ MALLAR MAGAZASI','PERAKENDE TICARET','KOSK','TICARET OBYEKTI','OBYEKT','OFIS','MEBEL MAGAZASI','TOPDAN SATIS ANBARI','TIKINTI MATERIALLARI MAGAZASI','RESTORAN','KAFE','SUPERMARKET','MINI MARKET')
load_receipts <- function() {
  base <- .fp_data_dir
  files <- file.path(base,c('fp_receipts.rds','fp_map.rds'))
  if(!all(file.exists(files))) stop('Məlumat tapılmadı. FP_RECEIPTS_DATA_DIR dəyişənini RDS fayllarının qovluğuna yönləndirin.')
  info <- file.info(files); signature <- list(version=4L,path=normalizePath(files),size=info$size,mtime=as.numeric(info$mtime))
  cache_dir <- Sys.getenv('FP_RECEIPTS_CACHE_DIR', unset=tools::R_user_dir('FPReceiptsShiny', 'cache')); dir.create(cache_dir,showWarnings=FALSE,recursive=TRUE)
  cache_file <- file.path(cache_dir,'receipts-v4.rds')
  manifest_file <- file.path(cache_dir,'manifest.rds')
  if(file.exists(cache_file) && file.exists(manifest_file) && identical(readRDS(manifest_file), signature)) {
    message('FP Receipts: hazırlıq keşi oxunur…'); result <- readRDS(cache_file)
    data.table::setDT(result$data); data.table::setDT(result$products); data.table::setDT(result$pos)
    return(result)
  }
  message('FP Receipts: xam məlumat oxunur…')
  raw <- readRDS(files[1]); mp <- data.table::as.data.table(readRDS(files[2]))
  stopifnot(all(c('pos','rec_date','rec_id','product_name','qnt','unit_price') %in% names(raw)))
  products_raw <- unique(raw$product_name); keys <- product_key(products_raw)
  # Keep original variants separate in data IDs; aggregate only on the normalized key.
  products <- data.table::data.table(id=seq_along(products_raw),name=repair_encoding(products_raw))
  products[, key := keys]
  products[, nonsale := grepl('\\bAVANS\\b',key) | grepl('^KREDIT\\b',key)]
  products[, generic := key=='' | grepl('^(SƏRBƏST|SERBEST|ƏRZAQ|ERZAQ|ÜMUMI|UMUMI|SATIŞ|SATISH|SATIS|MƏHSUL|MEHSUL)\\b',key)]
  products[, group_id := match(key,unique(key))]
  raw_pos <- unique(raw$pos); norm_pos <- pos_key(raw_pos); pos_names <- unique(norm_pos)
  pos <- data.table::data.table(id=seq_along(pos_names),name=pos_names,generic=pos_names %in% GENERIC_POS)
  alias <- data.table::data.table(name=norm_pos,alias=raw_pos)[,.(aliases=paste(unique(alias),collapse=' / '),variants=.N),by=name]
  pos <- merge(pos,alias,by='name',sort=FALSE); data.table::setorder(pos,id)
  dates <- seq(min(raw$rec_date),max(raw$rec_date),by='day')
  message('FP Receipts: yığcam analitik baza və xəritə hazırlanır…')
  dat <- data.table::data.table(day=as.integer(match(raw$rec_date,dates)),pos_id=as.integer(match(norm_pos[match(raw$pos,raw_pos)],pos_names)),product_id=as.integer(match(raw$product_name,products_raw)),qnt=as.numeric(raw$qnt)-1,price=as.numeric(raw$unit_price)-1)
  stopifnot(min(dat$qnt)>=0,min(dat$price)>=0,nrow(dat)==nrow(raw))
  meta <- list(rows=nrow(raw),raw_pos=length(raw_pos),normalized_pos=nrow(pos),raw_products=length(products_raw),damaged_pos=sum(grepl('?',raw_pos,fixed=TRUE)),damaged_products=sum(grepl('[ÃÉÂÄÅ]',products_raw)),map_rows=nrow(mp),invalid_margins=sum(abs(mp$profit_margin)>1,na.rm=TRUE),source=normalizePath(files),signature=signature,dates=dates,prepared=Sys.time())
  rm(raw,products_raw,raw_pos,norm_pos,keys); invisible(gc())
  mp[, key := product_key(product)]; mp[abs(profit_margin)>1,profit_margin:=NA_real_]
  mp <- unique(mp,by=c('period','key'))
  dat[, category:=3L]; dat[, margin:=NA_real_]
  # A per-month dictionary avoids joining ten million product strings.
  for(per in unique(as.integer(format(dates,'%Y%m')))) {
    mm <- mp[mp$period==per]; m <- match(products$key,mm$key)
    ty <- match(mm$product_type[m],c('FOOD','NON-FOOD')); ty[is.na(ty)] <- 3L
    ds <- which(as.integer(format(dates,'%Y%m'))==per)
    ix <- which(dat$day %in% ds); pi <- dat$product_id[ix]
    data.table::set(dat,i=ix,j='category',value=as.integer(ty[pi]))
    data.table::set(dat,i=ix,j='margin',value=mm$profit_margin[m][pi])
  }
  sales <- !products$nonsale[dat$product_id]
  daily <- dat[which(sales),.(n=.N,revenue=sum(qnt*price)),by=day]
  med <- median(daily$n); daily[,status:=ifelse(n>2*med,'Yığılmış data',ifelse(n<.5*med,'Natamam data','Normal'))]
  status <- rep('Data yoxdur',length(dates));status[daily$day] <- daily$status
  meta$status <- status;meta$day_median <- med
  meta$sales_rows <- sum(sales);meta$sales_revenue <- dat[which(sales),sum(qnt*price)]
  meta$corrected_all <- dat[,sum(qnt*price)];meta$raw_all <- dat[,sum((qnt+1)*(price+1))]
  meta$nonsales_rows <- sum(!sales)
  meta$source_hash <- vapply(files,digest::digest,character(1),algo='sha256',file=TRUE)
  result <- list(data=dat,products=products,pos=pos,meta=meta)
  tmp <- paste0(cache_file,'.tmp');saveRDS(result,tmp,compress=FALSE);file.rename(tmp,cache_file);saveRDS(signature,manifest_file)
  message('FP Receipts: baza hazırdır.'); result
}

# ── ANALİTİK HESABLAMALAR ─────────────────────────────────────────────────

filter_ids <- function(store, filters) {
  d<-store$data;m<-store$meta;pr<-store$products;ps<-store$pos
  keep <- d$day>=match(as.Date(filters$dates[1]),m$dates) & d$day<=match(as.Date(filters$dates[2]),m$dates)
  if(!isTRUE(filters$payments)) keep <- keep & !pr$nonsale[d$product_id]
  if(isTRUE(filters$concrete_pos)) keep <- keep & !ps$generic[d$pos_id]
  if(isTRUE(filters$concrete_product)) keep <- keep & !pr$generic[d$product_id]
  if(length(filters$pos)) keep <- keep & d$pos_id %in% as.integer(filters$pos)
  query<-trimws(filters$query %||% '')
  if(nchar(query)>0) {pid<-which(stringi::stri_detect_fixed(pr$key,toupper(query)));keep<-keep & d$product_id %in% pid}
  if(filters$category!='Hamısı')keep<-keep & d$category==match(filters$category,c('FOOD','NON-FOOD','Bilinmir'))
  if(filters$mode=='Ədədlə')keep<-keep & d$qnt==round(d$qnt)
  if(filters$mode=='Çəki ilə')keep<-keep & d$qnt!=round(d$qnt)
  if(filters$status!='Hamısı')keep<-keep & m$status[d$day]==filters$status
  if(filters$day_type!='Hamısı') {weekend<-as.POSIXlt(m$dates)$wday %in% c(0,6);keep<-keep & if(filters$day_type=='Həftə sonu')weekend[d$day] else !weekend[d$day]}
  shift<-if(isTRUE(filters$corrected))0 else 1
  if(is.finite(filters$min_price %||% NA_real_) && filters$min_price>0)keep<-keep & d$price+shift>=filters$min_price
  if(is.finite(filters$max_price %||% NA_real_))keep<-keep & d$price+shift<=filters$max_price
  which(keep %in% TRUE)
}
`%||%` <- function(x,y) if(is.null(x)||length(x)==0)y else x
metric_summary <- function(store,ids,corrected=TRUE) {
  d<-store$data;off<-if(corrected)0 else 1
  if(!length(ids))return(list(n=0L,revenue=0,median=NA_real_,mean=NA_real_,price=NA_real_,qnt=NA_real_,pos=0L,products=0L,mapped=0,mapped_revenue=0,profit=NA_real_,weighted=0,days=0L))
  q<-d$qnt[ids]+off;r<-q*(d$price[ids]+off);mapped<-d$category[ids]!=3L
  list(n=length(ids),revenue=sum(r),median=median(r),mean=mean(r),price=median(d$price[ids]+off),qnt=median(q),pos=data.table::uniqueN(d$pos_id[ids]),products=data.table::uniqueN(store$products$group_id[d$product_id[ids]]),mapped=mean(mapped),mapped_revenue=if(sum(r)>0)sum(r[mapped])/sum(r) else 0,profit=if(any(is.finite(d$margin[ids])))sum(r*d$margin[ids],na.rm=TRUE) else NA_real_,weighted=mean(d$qnt[ids]!=round(d$qnt[ids])),days=data.table::uniqueN(d$day[ids]))
}
daily_metrics <- function(store,ids,corrected=TRUE,range=range(store$meta$dates)) {
  off<-if(corrected)0 else 1;d<-store$data
  agg<-d[ids,.(n=.N,revenue=sum((qnt+off)*(price+off))),by=day]
  cal<-data.table::data.table(date=seq(as.Date(range[1]),as.Date(range[2]),by='day'))
  cal[,day:=match(date,store$meta$dates)];agg<-merge(cal,agg,by='day',all.x=TRUE,sort=FALSE);data.table::setorder(agg,date)
  # A zero filtered count does not mean the source day is absent.
  agg[,source_status:=store$meta$status[day]];agg[,observed:=source_status!='Data yoxdur']
  agg[observed & is.na(n),`:=`(n=0L,revenue=0)]
  agg[,avg:=ifelse(n>0,revenue/n,NA_real_)];agg
}
entity_metrics <- function(store,ids,corrected=TRUE,entity='pos') {
  off<-if(corrected)0 else 1;d<-store$data
  if(entity=='pos') {
    x<-d[ids,.(n=.N,revenue=sum((qnt+off)*(price+off)),days=data.table::uniqueN(day)),by=pos_id]
    x[,`:=`(name=store$pos$name[pos_id],generic=store$pos$generic[pos_id],id=as.character(pos_id))]
  } else {
    # Variant IDs share a normalized key. Group before ranking, as in the Rmd.
    x<-d[ids,.(n=.N,revenue=sum((qnt+off)*(price+off)),days=data.table::uniqueN(day)),by=.(group_id=store$products$group_id[product_id])]
    keys<-unique(store$products[,.(group_id,key,generic)],by='group_id');x<-merge(x,keys,by='group_id',sort=FALSE);x[,`:=`(name=key,id=as.character(group_id))];x[,key:=NULL]
  }
  x[,daily:=revenue/pmax(days,1L)];data.table::setorder(x,-revenue)
  x[,share:=if(sum(revenue)>0)100*revenue/sum(revenue) else 0];x[,cumulative:=cumsum(share)];x
}
price_distribution <- function(store,ids,corrected=TRUE) {
  d<-store$data;off<-if(corrected)0 else 1
  labels<-c('0','0–1','1–2','2–5','5–10','10–20','20–50','50–100','100+')
  x<-d[ids,.(price=price+off,revenue=(qnt+off)*(price+off))]
  x[,band:=cut(price,c(-Inf,0,1,2,5,10,20,50,100,Inf),labels=labels)]
  x<-x[,.(n=.N,revenue=sum(revenue)),by=band];x<-merge(data.table::data.table(band=factor(labels,levels=labels)),x,by='band',all.x=TRUE,sort=FALSE)
  x[is.na(n),`:=`(n=0L,revenue=0)];x[,`:=`(row_share=100*n/max(sum(n),1),revenue_share=100*revenue/max(sum(revenue),.Machine$double.eps))];data.table::setorder(x,band);x
}
fit_forecasts <- function(daily,test_n=5L,horizon=7L,normal_only=TRUE,confidence=.95) {
  a<-as.data.frame(daily);a<-a[!is.na(a$revenue) & a$n>0,,drop=FALSE]
  if(normal_only)a<-a[a$source_status=='Normal',,drop=FALSE]
  a<-a[order(a$date),,drop=FALSE]
  if(nrow(a)<max(12L,test_n+7L))return(list(ok=FALSE,message='Seçilmiş kəsimdə model üçün kifayət qədər gün yoxdur. Tarixi genişləndirin və ya filtrləri azaldın.'))
  a$weekend<-as.integer(as.POSIXlt(a$date)$wday %in% c(0,6));a$weekday<-as.POSIXlt(a$date)$wday;a$trend<-as.numeric(a$date-min(a$date))
  train<-head(a,-test_n);test<-tail(a,test_n)
  train_lm<-function(frame){terms<-c(if(length(unique(frame$weekend))>1)'weekend',if(length(unique(frame$trend))>1)'trend');stats::lm(reformulate(terms,response='revenue'),data=frame)}
  model<-train_lm(train);test$linear<-as.numeric(predict(model,test));test$average<-mean(train$revenue);test$last<-tail(train$revenue,1)
  wm<-tapply(train$revenue,train$weekday,mean);test$weekday_mean<-unname(wm[as.character(test$weekday)]);test$weekday_mean[is.na(test$weekday_mean)]<-mean(train$revenue)
  cols<-c('linear','average','last','weekday_mean');names<-c('Reqressiya','Sadə orta','Son gün','Həftə gününün ortası')
  scores<-data.frame(model=names,code=cols,MAE=sapply(cols,function(k)mean(abs(test$revenue-test[[k]]))),RMSE=sapply(cols,function(k)sqrt(mean((test$revenue-test[[k]])^2))),MAPE=sapply(cols,function(k)100*mean(abs(test$revenue-test[[k]])/test$revenue)),WAPE=sapply(cols,function(k)100*sum(abs(test$revenue-test[[k]]))/sum(test$revenue)))
  full<-train_lm(a);future<-data.frame(date=seq(max(a$date)+1,by='day',length.out=horizon));future$weekend<-as.integer(as.POSIXlt(future$date)$wday %in% c(0,6));future$trend<-as.numeric(future$date-min(a$date));future$weekday<-as.POSIXlt(future$date)$wday
  pred<-suppressWarnings(predict(full,future,interval='prediction',level=confidence));future$linear<-pred[,'fit'];future$low<-pred[,'lwr'];future$high<-pred[,'upr'];future$average<-mean(a$revenue);future$last<-tail(a$revenue,1)
  fwm<-tapply(a$revenue,a$weekday,mean);future$weekday_mean<-unname(fwm[as.character(future$weekday)]);future$weekday_mean[is.na(future$weekday_mean)]<-mean(a$revenue)
  ct<-summary(full)$coefficients;coeff<-data.frame(term=rownames(ct),estimate=ct[,1],p=ct[,4],row.names=NULL)
  wp<-if(length(unique(a$weekend))==2)suppressWarnings(wilcox.test(revenue~weekend,a,exact=FALSE)$p.value)else NA_real_
  list(ok=TRUE,train=train,test=test,history=a,future=future,scores=scores,coef=coeff,r2=summary(full)$r.squared,wilcox=wp,has_weekends=length(unique(train$weekend))==2,negative=any(future$linear<0),model=full)
}

# ── İSTİFADƏÇİ İNTERFEYSİ ─────────────────────────────────────────────────

chart_card <- function(title,subtitle=NULL,...,height=NULL) tags$section(class='chart-card',tags$div(class='card-heading',tags$div(tags$h3(title),if(!is.null(subtitle))tags$p(subtitle))),...)
page_intro <- function(eyebrow,title,description,action=NULL) tags$div(class='page-intro',tags$div(tags$div(class='eyebrow',eyebrow),tags$h1(title),tags$p(description)),action)
kpis <- function(id) uiOutput(id,class='kpi-grid')
nav_item <- function(id,label,ico) actionButton(paste0('nav_',id),label,icon=icon(ico),class=paste('rail-link',if(id=='overview')'active'),`data-view`=id)
build_ui <- function(store) {
  m<-store$meta
  fluidPage(theme=bslib::bs_theme(version=5,base_font='system-ui',primary='#0b7666',bg='#f3f5f7',fg='#172a3a'),
    tags$head(tags$title('FP Receipts | Analitika'),tags$meta(name='viewport',content='width=device-width, initial-scale=1'),tags$style(HTML(.fp_css)),tags$script(HTML(.fp_js))),
    tags$div(class='app-shell',
      tags$aside(class='rail',
        tags$div(class='brand',tags$span(class='brand-mark','FP'),tags$div(tags$strong('Receipts'),tags$small('ANALİTİKA STUDİYASI'))),
        tags$div(class='rail-caption','İŞ SAHƏSİ'),
        nav_item('overview','İcmal','chart-line'),nav_item('structure','Satış strukturu','chart-pie'),nav_item('entities','POS və məhsullar','store'),nav_item('quality','Anomaliyalar','triangle-exclamation'),
        tags$div(class='rail-caption','MODELLƏŞDİRMƏ'),nav_item('forecast','Proqnoz və fərziyyələr','wave-square'),nav_item('scenario','Ssenari laboratoriyası','sliders'),
        tags$div(class='rail-caption','MƏLUMAT'),nav_item('explorer','Məlumat araşdırıcısı','table'),nav_item('method','Metodologiya','book-open'),
        tags$div(class='rail-bottom',tags$span(class='status-dot'),tags$span('Yerli məlumat mənbəyi'),tags$strong('19 aprel – 31 may 2024'),tags$p('10 000 909 mənbə sətri'),actionButton('show_help','Qısa istifadə bələdçisi',icon=icon('circle-question'),class='help-button'))
      ),
      tags$main(class='main',
        tags$header(class='topbar',tags$div(class='breadcrumb',tags$button(id='mobile-menu',class='mobile-menu',`aria-label`='Menyunu aç','☰'),tags$span('FP Receipts'),tags$span(class='slash','/'),textOutput('current_page',inline=TRUE)),tags$div(class='top-actions',tags$span(id='busy_state',icon('spinner',class='fa-spin'),' Hesablanır…'),actionButton('restore_view','Yaddaşdakı görünüş',icon=icon('bookmark'),class='btn-quiet'),actionButton('save_view','Yadda saxla',icon=icon('floppy-disk'),class='btn-quiet'),checkboxInput('dark','Tünd görünüş',FALSE))),
        tags$section(class='filter-shell',
          tags$div(class='filter-top',tags$strong(icon('filter'),' Analiz kəsimi'),uiOutput('filter_summary',inline=TRUE),actionButton('reset','Sıfırla',icon=icon('rotate-left'),class='btn-quiet')),
          tags$div(class='filter-grid',dateRangeInput('dates','Tarix aralığı',start=min(m$dates),end=max(m$dates),min=min(m$dates),max=max(m$dates),format='dd.mm.yyyy',separator=' — ',language='az',weekstart=1),selectizeInput('pos','POS adı',choices=NULL,multiple=TRUE,options=list(placeholder='Bütün POS adları',maxItems=10)),textInput('query','Məhsul axtarışı',placeholder='Məsələn: BANAN'),actionButton('apply','Tətbiq et',icon=icon('arrow-right'),class='btn-apply')),
          tags$details(class='advanced',tags$summary(icon('sliders'),' Əlavə filtrlər və hesablama bazası'),
            tags$div(class='advanced-grid',selectInput('category','Məhsul növü',c('Hamısı','FOOD','NON-FOOD','Bilinmir')),selectInput('mode','Satış növü',c('Hamısı','Ədədlə','Çəki ilə')),selectInput('status','Günün keyfiyyət sinfi',c('Hamısı','Normal','Natamam data','Yığılmış data','Data yoxdur')),selectInput('day_type','Günün tipi',c('Hamısı','İş günü','Həftə sonu')),numericInput('min_price','Minimum vahid qiymət, AZN',0,min=0),numericInput('max_price','Maksimum qiymət (boş = hamısı)',NA,min=0)),
            tags$div(class='check-row',checkboxInput('corrected','Hesabat düzəlişi (−1)',TRUE),checkboxInput('payments','Avans və kredit ödənişləri daxil',FALSE),checkboxInput('concrete_pos','Yalnız konkret POS adları',FALSE),checkboxInput('concrete_product','Yalnız konkret məhsul adları',FALSE)),
            tags$p(class='microcopy','Düzəliş qnt və unit_price sütunlarının hər birindən 1 çıxır. Bu, hesabatın fərziyyəsidir. Mənbə sistemi ilə təsdiq tələb edir. Filtrlər “Tətbiq et” ilə yenilənir.')
          )
        ),
        uiOutput('draft_notice'),uiOutput('selection_notice'),
        tabsetPanel(id='view',type='hidden',
          tabPanel('İcmal',value='overview',
            page_intro('SATIŞLARA ÜMUMİ BAXIŞ','Məlumatın arxasındakı satış mənzərəsi','Gəliri, satış tezliyini və məlumat əhatəsini eyni kəsimdə izləyin.',downloadButton('report_html','Hesabatı endir',class='btn-outline')),
            kpis('overview_kpi'),
            tags$div(class='two-col wide-left',chart_card('Günlük satış dinamikası','Qrafikdə tarixə klikləyərək həmin günün detallarını açın.',tags$div(class='inline-controls',radioButtons('trend_metric',NULL,c('Gəlir'='revenue','Sətir sayı'='n','Orta sətir gəliri'='avg'),inline=TRUE)),plotlyOutput('trend',height='330px')),chart_card('Seçilmiş kəsimin portreti',NULL,uiOutput('overview_insights'))),
            tags$div(class='two-col',chart_card('Həftə günlərinin ritmi','Orta gəlir yalnız məlumat olan günlər üzrədir.',plotlyOutput('weekdays',height='270px')),chart_card('Əvvəlki dövrlə müqayisə','Eyni uzunluqda əvvəlki tarix aralığı. Mənbədən kənar günlər müqayisəyə daxil edilmir.',uiOutput('period_compare')))
          ),
          tabPanel('Satış strukturu',value='structure',
            page_intro('DESKRİPTİV TƏHLİL','Satışın strukturu və paylanması','Bahalı məhsulların, kəsr miqdarların və məhsul növlərinin gəlirdəki yerini araşdırın.'),
            kpis('structure_kpi'),
            tags$div(class='two-col wide-left',chart_card('Qiymət və gəlir payı','Vahid qiymət aralıqları üzrə. Sütuna klik həmin aralığı filtrə çevirir.',plotlyOutput('price_bands',height='330px')),chart_card('Satış növü','Tam və kəsr miqdar ayrımı hesabatın qəbuludur.',plotlyOutput('sales_modes',height='330px'))),
            tags$div(class='two-col',chart_card('Sətir gəlirinin paylanması','Müsbət gəlirlər üçün logarifmik intervallar. Sıfırlar ayrıca göstərilir.',plotlyOutput('distribution',height='300px')),chart_card('Məhsul xəritəsinin əhatəsi','Mənfəət yalnız marjası məlum olan sətirlər üzrə hesablanır.',plotlyOutput('category_chart',height='300px')))
          ),
          tabPanel('POS və məhsullar',value='entities',
            page_intro('REYTİNQ VƏ MÜQAYİSƏ','Gəlir hansı adlarda cəmlənir?','POS adları filialları birləşdirə bilər. Məhsullar normallaşdırılmış ad üzrə qruplaşdırılır.',downloadButton('entity_csv','Reytinq CSV',class='btn-outline')),
            tags$div(class='local-controls',radioButtons('entity','Obyekt',c('POS adları'='pos','Məhsul adları'='product'),inline=TRUE),selectInput('entity_metric','Sıralama',c('Ümumi gəlir'='revenue','Sətir sayı'='n','Orta günlük gəlir'='daily')),sliderInput('top_n','Göstərilən ad sayı',min=5,max=30,value=10,step=5),numericInput('min_days','Minimum aktiv gün',1,min=1,max=43),checkboxInput('rank_concrete','Ümumi adları gizlət',TRUE)),
            tags$div(class='two-col wide-left',chart_card('Seçilmiş reytinq','Sütuna klik obyekt profilini açır.',plotlyOutput('entity_rank',height='430px')),chart_card('Konsentrasiya',NULL,uiOutput('concentration'),plotlyOutput('pareto',height='245px'))),
            chart_card('Obyektləri qarşılaşdırın','Reytinqdəki ilk 1 000 addan 2–5 ad seçin. Günlük gəlirləri müqayisə edin.',selectizeInput('compare_entities',NULL,choices=NULL,multiple=TRUE,options=list(placeholder='Müqayisə üçün ad seçin',maxItems=5)),plotlyOutput('entity_comparison',height='300px')),
            chart_card('Tam reytinq','Axtarış, sıralama və sətrə kliklə profil.',DTOutput('entity_table'))
          ),
          tabPanel('Anomaliyalar',value='quality',
            page_intro('MƏLUMAT KEYFİYYƏTİ','Siqnalları satış davranışından ayırın','Tarix üzrə natamamlıq, ümumi adlar və xəritə boşluqları üçün araşdırma sahəsi.'),
            kpis('quality_kpi'),
            tags$div(class='two-col wide-left',chart_card('Həcm siqnalının həssaslığı','Seçilmiş kəsimin müşahidəli günləri üzrə medianla müqayisə. Səbəb deyil, ilkin siqnaldır.',tags$div(class='inline-controls',sliderInput('low_threshold','Aşağı hədd × median',.1,.9,.5,.05),sliderInput('high_threshold','Yuxarı hədd × median',1.2,5,2,.1)),plotlyOutput('quality_plot',height='320px')),chart_card('Araşdırma qeydləri',NULL,uiOutput('quality_notes'))),
            chart_card('Günlük keyfiyyət jurnalı','Mənbə statusu bütün normal satış bazasına, interaktiv siqnal isə cari kəsimə əsaslanır.',downloadButton('quality_csv','Jurnalı endir',class='btn-quiet'),DTOutput('quality_table'))
          ),
          tabPanel('Proqnoz',value='forecast',
            page_intro('PROQNOZ VƏ FƏRZİYYƏLƏR','Modeli sadə baza ilə sınaqdan keçirin','Xronoloji test, model müqayisəsi və fərziyyə testləri. Gələcək qiymətlər araşdırma üçündür.',downloadButton('forecast_csv','Proqnoz CSV',class='btn-outline')),
            tags$div(class='local-controls',sliderInput('test_days','Test üçün son günlər',3,10,5,1),sliderInput('horizon','Gələcək üfüq, gün',3,21,7,1),selectInput('forecast_model','Göstərilən model',c('Reqressiya'='linear','Sadə orta'='average','Son gün'='last','Həftə gününün ortası'='weekday_mean')),selectInput('confidence','Reqressiyanın intervalı',c('80%'=.8,'95%'=.95),selected=.95),checkboxInput('normal_only','Yalnız normal günlər',TRUE)),
            uiOutput('forecast_notice'),kpis('forecast_kpi'),
            tags$div(class='two-col wide-left',chart_card('Tarixi test və gələcək sınaq','Faktiki nəticələr, ayrıca test hissəsi və gələcək qiymətləndirmə.',plotlyOutput('forecast_plot',height='365px')),chart_card('Fərziyyələr və model',NULL,uiOutput('hypotheses'))),
            tags$div(class='two-col',chart_card('Modellərin test müqayisəsi','Eyni təlim və test günləri. Aşağı xəta daha yaxşıdır.',DTOutput('model_scores')),chart_card('Test günlərinin detalları','Faiz xətası faktiki gəlirə nisbətən hesablanır.',DTOutput('test_table')))
          ),
          tabPanel('Ssenari',value='scenario',
            page_intro('SSENARİ LABORATORİYASI','Qiymət və həcm dəyişsə nə olar?','Seçilmiş satış bazası üzərində şərti hesab. Tələb elastikliyi və müştəri reaksiyası modelləşdirilmir.'),
            tags$div(class='two-col scenario-layout',chart_card('Fərziyyələrinizi seçin','Dəyişikliklər bu bölmədə dərhal tətbiq olunur.',sliderInput('volume_change','Satış həcminin dəyişməsi, %',-50,100,10,1),sliderInput('price_change','Qiymət dəyişməsi, %',-30,50,5,1),sliderInput('margin_change','Məlum marjaya dəyişiklik, faiz bəndi',-10,10,0,.5),actionButton('scenario_reset','Ssenarini sıfırla',icon=icon('rotate-left'),class='btn-outline'),uiOutput('scenario_assumptions')),chart_card('Ssenarinin nəticəsi',NULL,uiOutput('scenario_kpi'),plotlyOutput('scenario_plot',height='300px'),downloadButton('scenario_csv','Ssenarini endir',class='btn-quiet'))),
            chart_card('Qiymət və həcm həssaslığı','Hüceyrənin üzərinə gəlin. Dəyərlər satış gəlirinin baza ilə müqayisədə dəyişməsidir.',plotlyOutput('sensitivity',height='340px'))
          ),
          tabPanel('Araşdırıcı',value='explorer',
            page_intro('MƏLUMAT ARAŞDIRICISI','Aqreqatdan məhsul sətrinə enin','Filtrlənmiş sətirləri axtarın, sıralayın və CSV kimi götürün. Xam mənbə faylları dəyişmir.'),
            tags$div(class='local-controls',selectInput('row_limit','Cədvəldə / ixracda ilk sətirlər',c('1 000'=1000,'5 000'=5000,'20 000'=20000,'100 000'=100000),selected=5000),downloadButton('rows_csv','Göstərilən sətirləri endir',class='btn-outline'),downloadButton('filters_json','Filtrləri JSON kimi endir',class='btn-quiet')),
            uiOutput('rows_notice'),chart_card('Satış sətirləri','Sətir № mənbədəki mövqedir, rec_id deyil. Ekran və CSV eyni açıq həddi istifadə edir.',DTOutput('rows_table'))
          ),
          tabPanel('Metodologiya',value='method',
            page_intro('METODOLOGİYA','Hesablamalar və analizin sərhədləri','Göstəricilərin hansı bazaya əsaslandığını və hansı qərarları dəstəklədiyini yoxlayın.'),
            tags$div(class='two-col',chart_card('Hesablama qaydaları',NULL,tags$dl(class='method-list',tags$dt('Analiz vahidi'),tags$dd('Bir məhsul əməliyyatı sətri. Unikal rec_id səbəbindən alış səbəti, orta qəbz və təkrar müştəri göstəriciləri hesablanmır.'),tags$dt('Hesabat düzəlişi'),tags$dd('qnt_adj = qnt − 1; price_adj = unit_price − 1. Gəlir = qnt_adj × price_adj. Düzəlişi bağladıqda məbləğlər xam qiymətlərdən hesablanır.'),tags$dt('Satış olmayan sətirlər'),tags$dd('Adında AVANS olan və normallaşdırılmış adı KREDIT ilə başlayan sətirlər ilkin olaraq çıxarılır. Kreditlə satılan məhsul adının sonunda KREDIT olması təkbaşına çıxarılma səbəbi deyil.'),tags$dt('Çəki / ədəd ayrımı'),tags$dd('Düzəlişli miqdarın kəsr olması çəki ilə satış kimi qəbul edilir. Mənbədə ayrıca ölçü vahidi yoxdur.'))),
            chart_card('Şərh məhdudiyyətləri',NULL,tags$dl(class='method-list',tags$dt('POS reytinqi'),tags$dd('Normallaşdırılmış adlar müqayisə olunur. Bir ad müxtəlif obyektləri və filialları birləşdirə bilər. Bu nəticə mağaza bazar payı deyil.'),tags$dt('Məhsul xəritəsi və mənfəət'),tags$dd('Ay + normallaşdırılmış məhsul adı ilə uyğunlaşdırma aparılır. Eyni ayda təkrar açarın ilk sətri qalır. |marja| > 1 dəyərləri hesablamadan çıxır. Mənfəət yalnız məlum marja üzrə təxmini məbləğdir, xalis mənfəət deyil.'),tags$dt('Tarix anomaliyaları'),tags$dd('İlkin status düzəlişli satış bazasında günlük sətir sayına görədir. Natamam və yığılmış etiketləri yoxlama siqnalıdır. Yükləmə jurnalları olmadan səbəbi təsdiq etmir.'),tags$dt('Proqnoz'),tags$dd('Son müşahidələr test üçün ayrılır. İntervallar yalnız reqressiya üçün şərti proqnoz intervallarıdır. Qısa, fasiləli tarixçə və beş iş günü üzrə test ümumiləşdirməni məhdudlaşdırır.')))),
            chart_card('Mənbə və hazırlıq məlumatı',NULL,uiOutput('source_info'))
          )
        ),
        tags$footer(class='app-footer',tags$span('FP Receipts · Yerli analitik iş sahəsi'),tags$span('AZN · 2024 · Sətir səviyyəsində təhlil'))
      )
    )
  )
}

# ── REAKTİV HESABLAMALAR VƏ İXRAC ─────────────────────────────────────────

fmt <- function(x,d=0) ifelse(is.finite(x),format(round(x,d),big.mark=' ',decimal.mark=',',nsmall=d,scientific=FALSE,trim=TRUE),'—')
compact <- function(x) if(!is.finite(x))'—' else if(abs(x)>=1e6)paste0(fmt(x/1e6,2),' mln') else if(abs(x)>=1e3)paste0(fmt(x/1e3,1),' min') else fmt(x,2)
kpi <- function(label,value,sub='',featured=FALSE,ico=NULL) tags$div(class=paste('kpi',if(featured)'featured'),tags$div(class='kpi-label',label,if(!is.null(ico))icon(ico)),tags$div(class='kpi-value',value),tags$div(class='kpi-sub',sub))
insight <- function(label,value,text='',accent=FALSE) tags$div(class='insight',tags$span(label),tags$strong(class=if(accent)'accent',value),tags$p(text))
notice <- function(text,info=FALSE) tags$div(class=paste('notice',if(info)'info'),icon(if(info)'circle-info' else 'triangle-exclamation'),' ',text)
pfmt <- function(x)if(!is.finite(x))'—' else if(x<.001)'< 0,001' else fmt(x,3)
make_server <- function(store) function(input,output,session) {
  C<-list(green='#168b76',blue='#3d7398',mint='#8bd1bd',navy='#153b50',amber='#d7a152',red='#c36757',gray='#9aaebb')
  m<-store$meta;d<-store$data
  defaults<-list(dates=as.character(range(m$dates)),pos=character(),query='',category='Hamısı',mode='Hamısı',status='Hamısı',day_type='Hamısı',min_price=0,max_price=NA_real_,corrected=TRUE,payments=FALSE,concrete_pos=FALSE,concrete_product=FALSE)
  state<-reactiveValues(applied=defaults,profile=NULL)
  collect<-function()list(dates=as.character(input$dates %||% as.Date(defaults$dates)),pos=as.character(input$pos %||% character()),query=input$query %||% '',category=input$category %||% 'Hamısı',mode=input$mode %||% 'Hamısı',status=input$status %||% 'Hamısı',day_type=input$day_type %||% 'Hamısı',min_price=as.numeric(input$min_price %||% 0),max_price=as.numeric(input$max_price %||% NA_real_),corrected=isTRUE(input$corrected),payments=isTRUE(input$payments),concrete_pos=isTRUE(input$concrete_pos),concrete_product=isTRUE(input$concrete_product))
  apply_filters<-function(f){
    dates<-as.Date(f$dates)
    if(length(dates)!=2||anyNA(dates)||dates[1]>dates[2]||dates[1]<min(m$dates)||dates[2]>max(m$dates)){showNotification('Tarix aralığı mənbə dövrü daxilində olmalıdır.',type='warning');return(FALSE)}
    if(is.finite(f$max_price)&&f$max_price<f$min_price){showNotification('Maksimum qiymət minimumdan kiçik ola bilməz.',type='warning');return(FALSE)}
    state$applied<-f;TRUE
  }
  set_controls<-function(f){
    updateDateRangeInput(session,'dates',start=f$dates[1],end=f$dates[2]);updateSelectizeInput(session,'pos',selected=f$pos);updateTextInput(session,'query',value=f$query)
    for(id in c('category','mode','status','day_type'))updateSelectInput(session,id,selected=f[[id]])
    for(id in c('min_price','max_price'))updateNumericInput(session,id,value=f[[id]])
    for(id in c('corrected','payments','concrete_pos','concrete_product'))updateCheckboxInput(session,id,value=f[[id]])
  }
  updateSelectizeInput(session,'pos',choices=setNames(as.character(store$pos$id),store$pos$name),server=TRUE)
  observeEvent(input$apply,{apply_filters(collect())})
  observeEvent(input$reset,{set_controls(defaults);state$applied<-defaults;showNotification('Bütün filtrlər sıfırlandı.',duration=2)})
  observeEvent(input$dark,{session$sendCustomMessage('fp_theme',isTRUE(input$dark))},ignoreInit=TRUE)
  views<-c(overview='İcmal',structure='Satış strukturu',entities='POS və məhsullar',quality='Anomaliyalar',forecast='Proqnoz və fərziyyələr',scenario='Ssenari laboratoriyası',explorer='Məlumat araşdırıcısı',method='Metodologiya')
  for(vv in names(views))local({view<-vv;observeEvent(input[[paste0('nav_',view)]],{updateTabsetPanel(session,'view',selected=view);session$sendCustomMessage('fp_nav',view)})})
  output$current_page<-renderText(views[input$view %||% 'overview'])
  ids<-reactive({filter_ids(store,state$applied)})
  sums<-reactive({metric_summary(store,ids(),state$applied$corrected)})
  daily<-reactive({daily_metrics(store,ids(),state$applied$corrected,as.Date(state$applied$dates))})
  require_data<-function(){validate(need(length(ids())>0,'Bu filtrlər üzrə sətir tapılmadı. Filtrləri azaldın və ya sıfırlayın.'))}
  pt<-reactive({if(isTRUE(input$dark))list(bg='#172c3a',fg='#b0c3cf',grid='#2b414e')else list(bg='#ffffff',fg='#758b99',grid='#ecf0f3')})
  finish<-function(p,ytitle='',margin=list(l=48,r=15,b=40,t=12),legend=FALSE){t<-pt();p %>% layout(paper_bgcolor=t$bg,plot_bgcolor=t$bg,font=list(family='system-ui, sans-serif',size=11,color=t$fg),margin=margin,xaxis=list(title='',showgrid=FALSE,zeroline=FALSE,linecolor=t$grid),yaxis=list(title=list(text=ytitle,font=list(size=10)),gridcolor=t$grid,zeroline=FALSE),showlegend=legend,legend=list(orientation='h',x=0,y=-.2,font=list(size=10))) %>% config(displaylogo=FALSE,modeBarButtonsToRemove=c('select2d','lasso2d','autoScale2d'),toImageButtonOptions=list(format='png',scale=2,filename='FP_Receipts'))}
  safe_dt<-function(x,selection='none',page=7,...) {DT::datatable(as.data.frame(x),rownames=FALSE,selection=selection,escape=TRUE,class='compact hover',options=list(pageLength=page,lengthMenu=c(7,15,30,100),scrollX=TRUE,language=list(search='Axtar:',lengthMenu='_MENU_ sətir',info='_TOTAL_ sətirdən _START_–_END_',infoEmpty='Sətir yoxdur',zeroRecords='Uyğun sətir tapılmadı',paginate=list(previous='Əvvəl',`next`='Sonra')),order=list()),...)}
  export_csv<-function(x,file){x<-as.data.frame(x);for(nm in names(x))if(is.character(x[[nm]]))x[[nm]]<-ifelse(grepl('^[=+@\t\r]',x[[nm]]),paste0("'",x[[nm]]),x[[nm]]);data.table::fwrite(x,file,bom=TRUE,na='')}
  output$filter_summary<-renderUI(tags$span(class='filter-meta',paste0(fmt(length(ids())),' sətir · ',if(state$applied$corrected)'−1 düzəlişi' else 'Xam məbləğlər',if(state$applied$payments)' · Ödənişlər daxil' else ' · Satış bazası')))
  output$draft_notice<-renderUI({req(!is.null(input$dates)); if(!isTRUE(all.equal(collect(),state$applied,check.attributes=FALSE)))tags$div(class='draft-notice',icon('pen-to-square'),' Filtr seçimləri dəyişib. Hesablamaları yeniləmək üçün “Tətbiq et” seçin.')})
  output$selection_notice<-renderUI({
    f<-state$applied
    if(!length(ids()))return(notice('Bu kəsimdə məlumat yoxdur. Filtrləri dəyişin və “Tətbiq et” seçin.'))
    if(!f$corrected)return(notice('Xam məbləğlər rejimi aktivdir. Qiymət və miqdar düzəlişi tətbiq olunmur. Satış növü və günün ilkin keyfiyyət sinfi hesabatın düzəlişli bazasına əsaslanır.'))
    if(f$payments)return(notice('Avans və kredit ödənişləri məbləğlərə daxildir. Nəticə yalnız məhsul satışı kimi şərh olunmamalıdır.'))
    NULL
  })
  output$overview_kpi<-renderUI({s<-sums();tagList(kpi('Satış gəliri',compact(s$revenue),'AZN · seçilmiş kəsim',TRUE,'coins'),kpi('Məhsul sətirləri',compact(s$n),paste(fmt(s$pos),'POS adı'),FALSE,'receipt'),kpi('Median sətir gəliri',paste(fmt(s$median,2),'₼'),'Tipik məhsul əməliyyatı',FALSE,'chart-simple'),kpi('Xəritə əhatəsi',paste0(fmt(s$mapped*100,2),'%'),'Sətirlərin uyğunlaşan payı',FALSE,'link'))})
  output$overview_insights<-renderUI({s<-sums();a<-daily();normal<-sum(a$source_status=='Normal');tagList(insight('Normal günlər',paste0(normal,' / ',nrow(a)),'Siniflər bütün mənbənin satış bazasına əsaslanır.',TRUE),insight('Orta və median gəlir',paste0(fmt(s$mean,2),' / ',fmt(s$median,2),' AZN'),'Böyük sətirlər orta dəyəri yüksəldə bilər.'),insight('Məhsul adları',fmt(s$products),'Normallaşdırılmış ad sayı. Ad bir SKU ilə eyni deyil.'),insight('Çəki ilə satış',paste0(fmt(100*s$weighted,1),'%'),'Kəsr miqdarlı sətirlərin payı.'))})
  output$trend<-renderPlotly({require_data();a<-daily();metric<-input$trend_metric %||% 'revenue';label<-switch(metric,revenue='Gəlir, AZN',n='Sətir sayı',avg='Orta sətir gəliri, AZN');a$tip<-paste0(format(a$date,'%d.%m.%Y'),'<br>',label,': ',fmt(a[[metric]],2),'<br>',a$source_status)
    p<-plot_ly(a,x=~date,y=a[[metric]],type='scatter',mode='lines+markers',source='trend',text=~tip,hoverinfo='text',line=list(color=C$green,width=2.5),marker=list(color=ifelse(a$source_status=='Normal',C$green,ifelse(a$source_status=='Yığılmış data',C$red,C$amber)),size=6),connectgaps=FALSE)%>%event_register('plotly_click');finish(p,label)
  })
  output$weekdays<-renderPlotly({require_data();a<-daily();a<-a[!is.na(revenue)];a[,wd:=as.POSIXlt(date)$wday];a[,wd:=ifelse(wd==0,7,wd)];b<-a[,.(mean=mean(revenue),days=.N),by=wd];data.table::setorder(b,wd);labs<-c('B.e.','Ç.a.','Ç.','C.a.','C.','Ş.','B.');p<-plot_ly(x=factor(labs[b$wd],levels=labs),y=b$mean,type='bar',textposition='none',marker=list(color=ifelse(b$wd>=6,C$amber,C$blue)),text=paste0(b$days,' müşahidəli gün'),hovertemplate='%{x}<br>%{y:,.0f} AZN<br>%{text}<extra></extra>');finish(p,'Orta günlük gəlir, AZN')%>%layout(xaxis=list(categoryorder='array',categoryarray=labs))})
  output$period_compare<-renderUI({f<-state$applied;a<-as.Date(f$dates);n<-as.integer(diff(a))+1;prior<-c(a[1]-n,a[1]-1);lo<-max(prior[1],min(m$dates));hi<-min(prior[2],max(m$dates));if(lo>hi)return(tags$div(class='empty',icon('calendar-xmark'),tags$p('Əvvəlki dövr üçün mənbə məlumatı yoxdur.'),tags$small('Müqayisə üçün daha qısa və dövrün sonuna yaxın tarix seçin.')))
    f$dates<-as.character(c(lo,hi));j<-filter_ids(store,f);prev<-metric_summary(store,j,f$corrected);s<-sums();delta<-if(prev$revenue>0)100*(s$revenue/prev$revenue-1)else NA_real_
    tagList(insight(paste(format(lo,'%d.%m'),'–',format(hi,'%d.%m.%Y')),paste(compact(prev$revenue),'AZN'),'Əvvəlki mövcud aralığın gəliri'),insight('Ümumi məbləğ fərqi',paste0(if(is.finite(delta)&&delta>0)'+' else '',fmt(delta,1),'%'),paste('Cari',s$days,'müşahidəli gün; əvvəlki',prev$days,'gün. Natamamlıq nəticəni dəyişə bilər.'),TRUE))})
  price<-reactive({price_distribution(store,ids(),state$applied$corrected)})
  output$structure_kpi<-renderUI({s<-sums();x<-price();cheap<-sum(x$row_share[1:4]);expensive<-x$revenue_share[9];q<-d$qnt[ids()];zero<-if(length(q))sum((q+if(state$applied$corrected)0 else 1)*(d$price[ids()]+if(state$applied$corrected)0 else 1)==0)else 0;tagList(kpi('Qiyməti ≤ 5 AZN',paste0(fmt(cheap,1),'%'),'Sətir payı',TRUE),kpi('100+ AZN məhsullar',paste0(fmt(expensive,1),'%'),'Ümumi məbləğdə pay'),kpi('Çəki ilə satış',paste0(fmt(s$weighted*100,1),'%'),'Sətir payı'),kpi('Sıfır məbləğli sətir',fmt(zero),'Pulsuz satış və ya qeyd xətası ola bilər'))})
  output$price_bands<-renderPlotly({require_data();x<-price();p<-plot_ly(x,x=~band,y=~row_share,type='bar',name='Sətir payı',marker=list(color=C$blue),source='price',customdata=seq_len(9),hovertemplate='%{x}<br>Sətir: %{y:.1f}%<extra></extra>')%>%add_bars(y=~revenue_share,name='Gəlir payı',marker=list(color=C$green),hovertemplate='%{x}<br>Gəlir: %{y:.1f}%<extra></extra>')%>%layout(barmode='group')%>%event_register('plotly_click');finish(p,'Pay, %',legend=TRUE)})
  output$sales_modes<-renderPlotly({require_data();off<-if(state$applied$corrected)0 else 1;x<-d[ids(),.(n=.N,revenue=sum((qnt+off)*(price+off))),by=.(mode=ifelse(qnt==round(qnt),'Ədədlə','Çəki ilə'))];p<-plot_ly(x,labels=~mode,values=~n,type='pie',hole=.69,textinfo='percent',textfont=list(size=13),marker=list(colors=c(C$green,C$blue)),hovertemplate='%{label}<br>%{value:,.0f} sətir<br>%{percent}<extra></extra>');p<-plotly::plotly_build(p);p$x$data[[1]]$type<-'pie';finish(p,margin=list(l=10,r=10,t=10,b=35),legend=TRUE)})
  output$distribution<-renderPlotly({require_data();off<-if(state$applied$corrected)0 else 1;r<-(d$qnt[ids()]+off)*(d$price[ids()]+off);positive<-r[r>0];validate(need(length(positive)>0,'Müsbət məbləğli sətir yoxdur.'));breaks<-c(0,.5,1,2,5,10,20,50,100,500,1000,Inf);labs<-c('0–0,5','0,5–1','1–2','2–5','5–10','10–20','20–50','50–100','100–500','500–1000','1000+');freq<-as.data.frame(table(cut(positive,breaks,labels=labs)));p<-plot_ly(freq,x=~Var1,y=~Freq,type='bar',marker=list(color=C$blue),hovertemplate='%{x} AZN<br>%{y:,.0f} sətir<extra></extra>');finish(p,'Sətir sayı')})
  output$category_chart<-renderPlotly({require_data();off<-if(state$applied$corrected)0 else 1;x<-d[ids(),.(revenue=sum((qnt+off)*(price+off))),by=category];x[,name:=c('FOOD','NON-FOOD','Bilinmir')[category]];p<-plot_ly(x,x=~name,y=~revenue,type='bar',marker=list(color=c(C$green,C$blue,C$gray)[x$category]),hovertemplate='%{x}<br>%{y:,.2f} AZN<extra></extra>');finish(p,'Gəlir, AZN')})
  entities<-reactive({entity_metrics(store,ids(),state$applied$corrected,input$entity %||% 'pos')})
  ranking<-reactive({x<-entities();x<-x[x$days>=(input$min_days %||% 1)];if(isTRUE(input$rank_concrete))x<-x[generic==FALSE];metric<-input$entity_metric %||% 'revenue';data.table::setorderv(x,metric,-1L);x})
  observeEvent(input$entity,{updateSelectizeInput(session,'compare_entities',selected=character())},ignoreInit=TRUE)
  output$entity_rank<-renderPlotly({require_data();x<-head(ranking(),input$top_n %||% 10);validate(need(nrow(x)>0,'Bu aktiv gün / ad şərti ilə obyekt yoxdur.'));metric<-input$entity_metric %||% 'revenue';xx<-x[.N:1];p<-plot_ly(x=xx[[metric]],y=factor(stringr::str_trunc(xx$name,34),levels=stringr::str_trunc(xx$name,34)),type='bar',source='rank',customdata=xx$id,text=xx$name,marker=list(color=ifelse(xx$generic,C$amber,C$blue)),hovertemplate='%{text}<br>%{x:,.2f}<extra></extra>')%>%event_register('plotly_click');finish(p,if(metric=='n')'Sətir sayı' else 'AZN',margin=list(l=155,r=20,t=10,b=40))})
  output$concentration<-renderUI({x<-data.table::copy(ranking());if(!nrow(x))return(tags$p('Obyekt yoxdur.'));data.table::setorder(x,-revenue);tot<-sum(x$revenue);top1<-if(tot>0)100*sum(head(x$revenue,max(1,ceiling(.01*nrow(x)))))/tot else 0;top10<-if(tot>0)100*sum(head(x$revenue,max(1,ceiling(.1*nrow(x)))))/tot else 0;tagList(insight('Ən böyük 10% adın gəlir payı',paste0(fmt(top10,1),'%'),paste(fmt(nrow(x)),'ad üzrə'),TRUE),tags$p(class='microcopy',paste('İlk 1% payı:',fmt(top1,1),'%. Ümumi ad və aktiv gün filtrləri bu bazaya təsir edir.')))})
  output$pareto<-renderPlotly({x<-data.table::copy(ranking());validate(need(nrow(x)>0,'Obyekt yoxdur.'));data.table::setorder(x,-revenue);ix<-unique(pmax(1L,round(seq(1,nrow(x),length.out=min(250,nrow(x))))));cum<-cumsum(x$revenue)/max(sum(x$revenue),.Machine$double.eps)*100;p<-plot_ly(x=100*ix/nrow(x),y=cum[ix],type='scatter',mode='lines',line=list(color=C$green,width=2),fill='tozeroy',fillcolor='rgba(22,139,118,.07)',hovertemplate='Adların %{x:.1f}%-i<br>Gəlirin %{y:.1f}%-i<extra></extra>');finish(p,'Yığılan gəlir, %',margin=list(l=42,r=10,b=35,t=8))%>%layout(xaxis=list(title='Adların payı, %'))})
  entity_display<-reactive({x<-ranking();data.frame(Ad=x$name,`Sətir sayı`=x$n,`Gəlir, AZN`=round(x$revenue,2),`Aktiv gün`=x$days,`Günlük gəlir, AZN`=round(x$daily,2),`Ümumi ad`=ifelse(x$generic,'Bəli','Xeyr'),check.names=FALSE)})
  output$entity_table<-renderDT({require_data();safe_dt(entity_display(),selection='single',page=10)%>%formatRound(c('Gəlir, AZN','Günlük gəlir, AZN'),digits=2,mark=' ',dec.mark=',')},server=TRUE)
  observe({req(input$view=='entities');x<-head(ranking(),1000);updateSelectizeInput(session,'compare_entities',choices=setNames(x$id,x$name),selected=isolate(input$compare_entities),server=TRUE)})
  output$entity_comparison<-renderPlotly({require_data();selected<-input$compare_entities;validate(need(length(selected)>=2,'Müqayisə üçün ilk 1 000 reytinq adından ən azı 2 ad seçin.'));off<-if(state$applied$corrected)0 else 1;x<-if((input$entity %||% 'pos')=='pos')d[ids()[d$pos_id[ids()] %in% as.integer(selected)],.(revenue=sum((qnt+off)*(price+off))),by=.(day,id=as.character(pos_id))]else d[ids()[store$products$group_id[d$product_id[ids()]] %in% as.integer(selected)],.(revenue=sum((qnt+off)*(price+off))),by=.(day,id=as.character(store$products$group_id[product_id]))];ee<-entities();x[,`:=`(name=ee$name[match(id,ee$id)],date=m$dates[day])];p<-plot_ly(x,x=~date,y=~revenue,color=~name,type='scatter',mode='lines+markers',colors=c(C$green,C$blue,C$amber,C$red,C$gray),hovertemplate='%{x}<br>%{y:,.2f} AZN<extra>%{fullData.name}</extra>');finish(p,'Gəlir, AZN',legend=TRUE)})
  quality<-reactive({x<-data.table::copy(daily());med<-median(x$n[!is.na(x$n)]);lo<-input$low_threshold %||% .5;hi<-input$high_threshold %||% 2;x[,signal:=ifelse(is.na(n),'Data yoxdur',ifelse(n>hi*med,'Yüksək həcm',ifelse(n<lo*med,'Aşağı həcm','Normal')))];x[,ratio:=if(med>0)n/med else NA_real_];x})
  output$quality_kpi<-renderUI({a<-quality();s<-sums();tagList(kpi('Normal gün',fmt(sum(a$signal=='Normal')),paste('Cari kəsimdə',nrow(a),'təqvim günü'),TRUE),kpi('Aşağı / yüksək həcm',paste(sum(a$signal=='Aşağı həcm'),'/',sum(a$signal=='Yüksək həcm')),'İnteraktiv hədlər üzrə siqnallar'),kpi('Məlumatı olmayan gün',fmt(sum(a$signal=='Data yoxdur')),'Sıfır satış kimi qəbul edilmir'),kpi('Xəritədən kənar sətir',paste0(fmt(100*(1-s$mapped),2),'%'),'Məhsul növü məlum deyil'))})
  output$quality_plot<-renderPlotly({require_data();a<-quality();cols<-c('Normal'=C$blue,'Aşağı həcm'=C$amber,'Yüksək həcm'=C$red,'Data yoxdur'=C$gray);p<-plot_ly(a,x=~date,y=~n,type='bar',marker=list(color=unname(cols[a$signal])),text=~signal,hovertemplate='%{x}<br>%{y:,.0f} sətir<br>%{text}<extra></extra>');finish(p,'Sətir sayı')})
  output$quality_notes<-renderUI({f<-state$applied;j<-ids();r<-(d$qnt[j]+if(f$corrected)0 else 1)*(d$price[j]+if(f$corrected)0 else 1);tot<-sum(r);gp<-if(tot>0)100*sum(r[store$pos$generic[d$pos_id[j]]])/tot else 0;gpr<-if(tot>0)100*sum(r[store$products$generic[d$product_id[j]]])/tot else 0;tagList(insight('Ümumi POS adlarının gəlir payı',paste0(fmt(gp,1),'%'),'MAGAZA və MARKET kimi adlar mağaza identifikatoru deyil.'),insight('Ümumi məhsul adlarının gəlir payı',paste0(fmt(gpr,1),'%'),'Məhsul detalları məlum deyil.'),insight('Xam mətndə kodlaşdırma',paste(fmt(m$damaged_pos),'POS adı'),paste(fmt(m$damaged_products),'məhsul adında kodlaşdırma siqnalı var. Məhsul adlarına bərpa qaydası tətbiq olunub.')),
    tags$p(class='microcopy','19 aprel piki məlumat yığılması ilə bağlı ola bilər. Yükləmə jurnalları olmadan bunu təsdiqləmək mümkün deyil.'))})
  quality_display<-reactive({a<-quality();data.frame(Tarix=as.character(a$date),`Sətir sayı`=a$n,`Gəlir, AZN`=round(a$revenue,2),`Medianın misli`=round(a$ratio,2),`İnteraktiv siqnal`=a$signal,`Mənbə statusu`=a$source_status,check.names=FALSE)})
  output$quality_table<-renderDT({safe_dt(quality_display(),page=10)},server=TRUE)
  forecast<-reactive({fit_forecasts(daily(),as.integer(input$test_days %||% 5),as.integer(input$horizon %||% 7),isTRUE(input$normal_only),as.numeric(input$confidence %||% .95))})
  require_fit<-function(){f<-forecast();validate(need(f$ok,f$message));f}
  output$forecast_notice<-renderUI({f<-forecast();if(!f$ok)return(notice(f$message));notice(paste0('Nəticələr ',nrow(f$train),' təlim və ',nrow(f$test),' test gününə əsaslanır. ',if(all(f$test$weekend==0))'Testin bütün günləri iş günüdür. ' else '',if(!f$has_weekends)'Təlimdə hər iki gün tipi yoxdur. ' else '', 'Gələcək hissə şərti sınaqdır, etibarlı əməliyyat planı kimi qəbul edilməməlidir.'))})
  output$forecast_kpi<-renderUI({f<-forecast();if(!f$ok)return(NULL);sc<-f$scores[f$scores$code==(input$forecast_model %||% 'linear'),];best<-f$scores$model[which.min(f$scores$MAE)];tagList(kpi('Test MAE',paste(compact(sc$MAE),'₼'),'Orta mütləq xəta',TRUE),kpi('Test MAPE',paste0(fmt(sc$MAPE,1),'%'),'Düzgünlük ehtimalı deyil'),kpi('Tam model R²',fmt(f$r2,3),'Bütün seçilmiş model günləri üzrə'),kpi('Ən aşağı MAE',best,'Eyni tarixi test üzrə'))})
  output$forecast_plot<-renderPlotly({f<-require_fit();code<-input$forecast_model %||% 'linear';a<-f$history;b<-f$test;future<-f$future;p<-plot_ly()%>%add_trace(x=a$date,y=a$revenue,type='scatter',mode='lines+markers',name='Faktiki',line=list(color=C$blue,width=2),marker=list(size=5))%>%add_trace(x=b$date,y=b[[code]],type='scatter',mode='lines+markers',name='Test proqnozu',line=list(color=C$amber,width=2),marker=list(size=6));if(code=='linear')p<-p%>%add_trace(x=c(future$date,rev(future$date)),y=c(future$high,rev(future$low)),type='scatter',mode='lines',fill='toself',fillcolor='rgba(22,139,118,.12)',line=list(color='transparent'),name=paste0(round(as.numeric(input$confidence %||% .95)*100),'% interval'),hoverinfo='skip');p<-p%>%add_trace(x=future$date,y=future[[code]],type='scatter',mode='lines+markers',name='Gələcək sınaq',line=list(color=C$green,width=2,dash='dash'),marker=list(size=5))%>%layout(shapes=list(list(type='line',x0=min(b$date),x1=min(b$date),y0=0,y1=1,yref='paper',line=list(color=C$amber,width=1,dash='dot'))));finish(p,'Gəlir, AZN',legend=TRUE)})
  output$hypotheses<-renderUI({f<-forecast();if(!f$ok)return(NULL);row<-f$coef[f$coef$term=='weekend',];trend<-f$coef[f$coef$term=='trend',];tagList(insight('İş günü / həftə sonu, Wilcoxon',paste('p',pfmt(f$wilcox)),if(!is.finite(f$wilcox))'İki gün tipi üzrə kifayət qədər məlumat yoxdur.' else if(f$wilcox<.05)'H₀ 5% səviyyəsində rədd edilir. Səbəb əlaqəsi müəyyənləşmir.' else 'H₀ rədd edilmir. Bu, günlərin eyni olduğunu sübut etmir.',TRUE),insight('Həftə sonu əmsalı',if(nrow(row))paste(fmt(row$estimate),'AZN')else 'Hesablanmır',if(nrow(row))paste('Reqressiya p',pfmt(row$p))else 'Təlimdə gün tipi dəyişmir.'),insight('Gündəlik trend',if(nrow(trend))paste(fmt(trend$estimate),'AZN / gün')else 'Hesablanmır',if(nrow(trend))paste('Reqressiya p',pfmt(trend$p))else ''),tags$p(class='microcopy','Reqressiya əmsalları bütün seçilmiş model günlərindən, test xətaları isə ayrıca təlimdən hesablanır.'))})
  output$model_scores<-renderDT({f<-require_fit();sc<-f$scores;sc$code<-NULL;names(sc)<-c('Model','MAE, AZN','RMSE, AZN','MAPE, %','WAPE, %');safe_dt(sc,page=4)%>%formatRound(2:5,digits=2,mark=' ',dec.mark=',')},server=TRUE)
  test_display<-reactive({f<-require_fit();code<-input$forecast_model %||% 'linear';data.frame(Tarix=as.character(f$test$date),`Faktiki, AZN`=round(f$test$revenue,2),`Proqnoz, AZN`=round(f$test[[code]],2),`Xəta, %`=round(100*abs(f$test$revenue-f$test[[code]])/f$test$revenue,1),check.names=FALSE)})
  output$test_table<-renderDT({safe_dt(test_display(),page=5)},server=TRUE)
  scenario<-reactive({s<-sums();f<-state$applied;v<-1+(input$volume_change %||% 10)/100;pr<-1+(input$price_change %||% 5)/100;delta<-(input$margin_change %||% 0)/100;j<-ids();r<-(d$qnt[j]+if(f$corrected)0 else 1)*(d$price[j]+if(f$corrected)0 else 1);known<-is.finite(d$margin[j]);mar<-d$margin[j][known]+delta;profit<-if(any(known))sum(r[known]*v*pr*mar)else NA_real_;list(revenue=s$revenue*v*pr,delta=s$revenue*(v*pr-1),profit=profit,base=s$revenue,base_profit=s$profit,factor=v*pr,invalid=sum(abs(mar)>1),mapped=s$mapped_revenue)})
  output$scenario_kpi<-renderUI({x<-scenario();tagList(kpi('Ssenari gəliri',paste(compact(x$revenue),'₼'),paste0(if(x$factor>=1)'+' else '',fmt((x$factor-1)*100,1),'% baza ilə müqayisə'),TRUE),kpi('Məbləğ fərqi',paste(if(x$delta>0)'+' else '',compact(x$delta),'₼'),'Qiymət × həcm təsiri'))})
  output$scenario_assumptions<-renderUI({x<-scenario();tagList(notice(paste('Dəyişiklik seçilmiş kəsimin bütün sətirlərinə eyni əmsalla tətbiq olunur. Həcm × qiymət əmsalı:',fmt(x$factor,3)),TRUE),insight('Məlum marja üzrə şərti mənfəət',paste(compact(x$profit),'AZN'),paste('Xəritələnmiş gəlir payı',fmt(100*x$mapped,2),'%. Bütün satışın mənfəəti deyil.')),if(x$invalid>0)notice(paste(fmt(x$invalid),'marja dəyəri ssenaridə [−1,1] həddindən çıxır. Fərziyyəni nəzərdən keçirin.')))})
  output$scenario_plot<-renderPlotly({x<-scenario();p<-plot_ly(x=c('Baza','Ssenari'),y=c(x$base,x$revenue),type='bar',marker=list(color=c(C$gray,C$green)),hovertemplate='%{x}<br>%{y:,.2f} AZN<extra></extra>');finish(p,'Gəlir, AZN')})
  output$sensitivity<-renderPlotly({vol<-seq(-30,50,10);pr<-seq(-20,30,5);z<-outer(vol,pr,function(v,p)100*((1+v/100)*(1+p/100)-1));p<-plot_ly(x=pr,y=vol,z=z,type='heatmap',colorscale=list(c(0,'#e4b5a8'),c(.4,'#f2f5f1'),c(1,'#0b7666')),colorbar=list(title='%'),hovertemplate='Qiymət: %{x}%<br>Həcm: %{y}%<br>Gəlir dəyişməsi: %{z:.1f}%<extra></extra>');finish(p,'Həcm dəyişməsi, %')%>%layout(xaxis=list(title='Qiymət dəyişməsi, %'))})
  observeEvent(input$scenario_reset,{updateSliderInput(session,'volume_change',value=0);updateSliderInput(session,'price_change',value=0);updateSliderInput(session,'margin_change',value=0)})
  explorer<-reactive({j<-head(ids(),as.integer(input$row_limit %||% 5000));f<-state$applied;off<-if(f$corrected)0 else 1;data.frame(`Sətir №`=j,Tarix=as.character(m$dates[d$day[j]]),POS=store$pos$name[d$pos_id[j]],Məhsul=store$products$name[d$product_id[j]],Miqdar=round(d$qnt[j]+off,5),`Vahid qiymət, AZN`=round(d$price[j]+off,5),`Məbləğ, AZN`=round((d$qnt[j]+off)*(d$price[j]+off),2),Növ=c('FOOD','NON-FOOD','Bilinmir')[d$category[j]],`Marja, %`=round(100*d$margin[j],2),`Mənbə statusu`=m$status[d$day[j]],check.names=FALSE)})
  output$rows_notice<-renderUI(notice(paste0('Filtr üzrə ',fmt(length(ids())),' sətirdən ilk ',fmt(min(length(ids()),as.integer(input$row_limit %||% 5000))),' sətir göstərilir və CSV-yə çıxır. Cədvəldəki əlavə axtarış ixracı dəyişmir.'),TRUE))
  output$rows_table<-renderDT({safe_dt(explorer(),page=10)},server=TRUE)
  open_profile<-function(kind,id,name){state$profile<-list(kind=kind,id=id,name=name);showModal(modalDialog(title=name,size='l',uiOutput('profile_summary'),plotlyOutput('profile_plot',height='280px'),tags$p(class='microcopy','Profil cari tətbiq edilmiş filtrlər daxilindədir.'),footer=tagList(modalButton('Bağla'),actionButton('profile_filter',if(kind=='product')'Bu adla axtar' else 'Filtrə tətbiq et',class='btn-apply'))))}
  observeEvent(event_data('plotly_click',source='trend'),{e<-event_data('plotly_click',source='trend');req(e$x);dt<-as.Date(as.character(e$x));req(!is.na(dt));open_profile('day',match(dt,m$dates),format(dt,'%d.%m.%Y'))},ignoreInit=TRUE)
  observeEvent({req(input$view=='entities');suppressWarnings(event_data('plotly_click',source='rank'))},{e<-suppressWarnings(event_data('plotly_click',source='rank'));req(e$customdata);x<-entities();i<-match(as.character(e$customdata[1]),x$id);req(!is.na(i));open_profile(input$entity %||% 'pos',x$id[i],x$name[i])},ignoreInit=TRUE)
  observeEvent(input$entity_table_rows_selected,{i<-input$entity_table_rows_selected;req(length(i)==1);x<-ranking();req(i<=nrow(x));open_profile(input$entity %||% 'pos',x$id[i],x$name[i])})
  profile_ids<-reactive({pr<-state$profile;req(pr);j<-ids();switch(pr$kind,day=j[d$day[j]==as.integer(pr$id)],pos=j[d$pos_id[j]==as.integer(pr$id)],product=j[store$products$group_id[d$product_id[j]]==as.integer(pr$id)])})
  output$profile_summary<-renderUI({s<-metric_summary(store,profile_ids(),state$applied$corrected);tags$div(class='kpi-grid',kpi('Gəlir',compact(s$revenue),'AZN',TRUE),kpi('Sətir sayı',fmt(s$n)),kpi('Median gəlir',fmt(s$median,2),'AZN'),kpi('Aktiv gün',fmt(s$days)))})
  output$profile_plot<-renderPlotly({pr<-state$profile;j<-profile_ids();if(pr$kind=='day'){x<-entity_metrics(store,j,state$applied$corrected,'pos');x<-head(x,8);p<-plot_ly(x=x$revenue,y=factor(stringr::str_trunc(x$name,30),levels=rev(stringr::str_trunc(x$name,30))),type='bar',marker=list(color=C$blue));finish(p,'Gəlir, AZN',margin=list(l=170,r=15,b=40,t=10))}else{a<-daily_metrics(store,j,state$applied$corrected,as.Date(state$applied$dates));finish(plot_ly(a,x=~date,y=~revenue,type='scatter',mode='lines+markers',line=list(color=C$green,width=2)),'Gəlir, AZN')}})
  observeEvent(input$profile_filter,{pr<-state$profile;f<-state$applied;if(pr$kind=='day')f$dates<-rep(as.character(m$dates[as.integer(pr$id)]),2)else if(pr$kind=='pos')f$pos<-as.character(pr$id)else f$query<-pr$name;set_controls(f);state$applied<-f;removeModal()})
  observeEvent({req(input$view=='structure');suppressWarnings(event_data('plotly_click',source='price'))},{e<-suppressWarnings(event_data('plotly_click',source='price'));req(e$x);i<-match(as.character(e$x),as.character(price()$band));req(!is.na(i));edges<-c(0,0,1,2,5,10,20,50,100,Inf);f<-state$applied;f$min_price<-if(i==1)0 else edges[i]+1e-7;f$max_price<-if(is.finite(edges[i+1]))edges[i+1] else NA_real_;state$applied<-f;set_controls(f);showNotification(paste('Qiymət filtri:',e$x,'AZN'),duration=3)},ignoreInit=TRUE)
  observeEvent(input$save_view,{session$sendCustomMessage('fp_save_view',state$applied)})
  observeEvent(input$restore_view,{session$sendCustomMessage('fp_restore_view',list())})
  observeEvent(input$view_storage_result,{showNotification(if(isTRUE(input$view_storage_result$ok))'Tətbiq edilmiş filtrlər bu brauzerdə yadda saxlandı.' else 'Brauzerin yerli yaddaşı əlçatan deyil.',type=if(isTRUE(input$view_storage_result$ok))'message'else'warning')})
  observeEvent(input$restore_payload,{f<-input$restore_payload$state;if(is.null(f)){showNotification('Bu brauzerdə yadda saxlanmış görünüş yoxdur.');return()};f<-modifyList(defaults,f[names(f) %in% names(defaults)]);f$pos<-as.character(unlist(f$pos));f$dates<-as.character(unlist(f$dates));if(is.null(f$max_price)||!length(f$max_price))f$max_price<-NA_real_;if(apply_filters(f))set_controls(f)})
  output$source_info<-renderUI(tags$div(class='source-grid',tags$div(tags$strong('Satış mənbəyi'),tags$p(basename(m$source[1])),tags$p('Sətir sayı: ',fmt(m$rows)),tags$code(m$source_hash[1])),tags$div(tags$strong('Məhsul xəritəsi'),tags$p(basename(m$source[2])),tags$p('Sətir sayı: ',fmt(m$map_rows)),tags$code(m$source_hash[2])),tags$div(tags$strong('Hazırlıq vaxtı'),tags$p(format(m$prepared,'%d.%m.%Y %H:%M')),tags$p('Orijinallar yalnız oxunur. Keş mənbə ölçüsü və dəyişmə vaxtı ilə yenilənir.')),tags$div(tags$strong('Tarix və məbləğlər'),tags$p('Məlumat dövrü: 19.04–31.05.2024'),tags$p('Valyuta: AZN. Xülasə məbləğləri yuvarlaqlaşdırılır.'))))
  observeEvent(input$show_help,{showModal(modalDialog(title='Analitika iş sahəsindən istifadə',tags$ol(tags$li('Tarix, POS və ya məhsul seçin. “Tətbiq et” düyməsini basın. Klaviatura: Ctrl/Cmd + Enter.'),tags$li('“Əlavə filtrlər” bölməsində hesab bazasını və keyfiyyət sinfini dəyişin.'),tags$li('Günlük qrafikdə tarixə, reytinqdə isə sütuna klikləyərək profil açın.'),tags$li('Qiymət qrafikində sütuna klik həmin aralığı bütün ekranlara tətbiq edir.'),tags$li('Proqnoz ekranında eyni test üzrə modelləri müqayisə edin. Ssenari ekranı şərti hesab üçündür.'),tags$li('Görünüşü bu brauzerdə yadda saxlayın. CSV və HTML ixracları cari tətbiq edilmiş kəsimə əsaslanır.')),easyClose=TRUE,footer=modalButton('Başlayaq')) )})
  output$entity_csv<-downloadHandler(filename=function()paste0('FP_reytinq_',Sys.Date(),'.csv'),content=function(file)export_csv(entity_display(),file))
  output$quality_csv<-downloadHandler(filename=function()paste0('FP_keyfiyyet_',Sys.Date(),'.csv'),content=function(file)export_csv(quality_display(),file))
  output$rows_csv<-downloadHandler(filename=function()paste0('FP_setirler_ilk_',nrow(explorer()),'.csv'),content=function(file)export_csv(explorer(),file))
  output$filters_json<-downloadHandler(filename='FP_filtrler.json',content=function(file)jsonlite::write_json(state$applied,file,pretty=TRUE,auto_unbox=TRUE,na='null'))
  output$forecast_csv<-downloadHandler(filename='FP_proqnoz.csv',content=function(file){f<-forecast();if(!f$ok){export_csv(data.frame(Qeyd=f$message),file);return()};x<-f$future;x$low<-if((input$forecast_model %||% 'linear')=='linear')x$low else NA_real_;x$high<-if((input$forecast_model %||% 'linear')=='linear')x$high else NA_real_;export_csv(x,file)})
  output$scenario_csv<-downloadHandler(filename='FP_ssenari.csv',content=function(file){x<-scenario();export_csv(data.frame(baza_geliri=x$base,ssenari_geliri=x$revenue,ferq=x$delta,hecm_faiz=input$volume_change,qiymet_faiz=input$price_change,marja_faiz_bendi=input$margin_change,melum_marja_uzre_menfeet=x$profit,xeritelendirilmis_gelir_payi=x$mapped,qeyd='Şərti ssenari. Tələb elastikliyi modelləşdirilmir.'),file)})
  output$report_html<-downloadHandler(filename=function()paste0('FP_Hesabat_',Sys.Date(),'.html'),content=function(file){
    s<-sums();f<-state$applied;qa<-quality_display();fc<-forecast();ent<-head(entity_metrics(store,ids(),f$corrected,'pos'),15)
    htable<-function(x)tags$table(tags$thead(tags$tr(lapply(names(x),tags$th))),tags$tbody(lapply(seq_len(nrow(x)),function(i)tags$tr(lapply(x[i,,drop=FALSE],function(v)tags$td(as.character(v)))))))
    doc<-tags$html(lang='az',tags$head(tags$meta(charset='UTF-8'),tags$title('FP Receipts — hesabat'),tags$style('body{font:15px system-ui;color:#183347;max-width:1100px;margin:50px auto;padding:0 24px}h1{font-size:38px}h2{margin-top:45px;color:#0b7666}table{border-collapse:collapse;width:100%;font-size:12px}th,td{padding:9px;border-bottom:1px solid #dce6e9;text-align:left}th{background:#edf4f3}.note{background:#f8eddb;padding:18px;line-height:1.8}pre{white-space:pre-wrap;background:#f4f6f7;padding:16px}')),tags$body(tags$h1('FP Receipts'),tags$p('Cari analiz kəsiminin hesabatı'),tags$p(paste(f$dates,collapse=' — ')),tags$div(class='note',paste('Hesablama bazası:',if(f$corrected)'qnt − 1 və unit_price − 1'else'xam dəyərlər','.',if(f$payments)'Avans və kredit ödənişləri daxildir.'else'Satış olmayan ödənişlər çıxarılıb.','Bütün göstəricilər sətir səviyyəsindədir. POS adları mağaza identifikatoru deyil.')),tags$h2('1. Deskriptiv təhlil'),htable(data.frame(Göstərici=c('Məbləğ, AZN','Sətir sayı','Median sətir gəliri, AZN','POS adı','Xəritə əhatəsi, %'),Dəyər=c(fmt(s$revenue,2),fmt(s$n),fmt(s$median,2),fmt(s$pos),fmt(s$mapped*100,2)))),tags$h3('İlk 15 POS adı'),htable(data.frame(Ad=ent$name,`Gelir_AZN`=round(ent$revenue,2),Setir=ent$n)),tags$h2('2. Anomaliyalar'),tags$p('Aşağı və yüksək həcm diaqnostik siqnaldır. Mənbə səbəbləri ayrıca yoxlanmalıdır.'),htable(qa),tags$h2('3. Proqnoz və fərziyyələr'),if(fc$ok)tagList(tags$p(paste(nrow(fc$train),'təlim,',nrow(fc$test),'test günü. Gələcək hissə şərti qiymətləndirmədir.')),htable(fc$scores[,c('model','MAE','RMSE','MAPE','WAPE')]),tags$p(paste('Wilcoxon p',pfmt(fc$wilcox),' Tam model R²',fmt(fc$r2,3))))else tags$p(fc$message),tags$h2('4. Xülasə'),tags$p('Məlumat tamlığı, −1 düzəlişinin təsdiqi və POS/məhsul identifikatorları analizin prioritetləridir. Məhsul növü və mənfəət nəticələri yalnız xəritələnmiş nümunəyə aiddir.'),tags$h3('Tətbiq edilmiş filtrlər'),tags$pre(jsonlite::toJSON(f,pretty=TRUE,auto_unbox=TRUE,na='null')),tags$p('Mənbələr: fp_receipts.rds, fp_map.rds; DA_Yekun_Layihe_Ramin1.Rmd və HTML hesabatının qaydaları.')))
    writeLines(paste0('<!DOCTYPE html>\n',as.character(doc)),file,useBytes=TRUE)
  })
}

# ── TƏTBİQİN İŞƏ SALINMASI ────────────────────────────────────────────────

.fp_store <- load_receipts()
.fp_app <- shiny::shinyApp(ui = build_ui(.fp_store), server = make_server(.fp_store))

# BUILD_ONLY yalnız avtomatlaşdırılmış yoxlama üçündür; adi istifadədə lazım deyil.
if (!isTRUE(getOption('FP_RECEIPTS_BUILD_ONLY', FALSE))) {
  .fp_port_text <- Sys.getenv('FP_SHINY_PORT', unset = '')
  .fp_port <- if (nzchar(.fp_port_text)) suppressWarnings(as.integer(.fp_port_text)) else NULL
  if (nzchar(.fp_port_text) && (is.na(.fp_port) || .fp_port < 1L || .fp_port > 65535L)) {
    stop('FP_SHINY_PORT 1–65535 arasında tam ədəd olmalıdır.', call. = FALSE)
  }
  .fp_open_browser <- tolower(Sys.getenv('FP_OPEN_BROWSER', unset = '1')) %in% c('1', 'true', 'yes')
  shiny::runApp(.fp_app, host = '127.0.0.1', port = .fp_port, launch.browser = .fp_open_browser)
}
