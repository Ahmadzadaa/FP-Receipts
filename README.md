# FP Receipts — İnteraktiv satış analitikası

Azərbaycan dilində **R Shiny** tətbiqi, analitik hesabat və PowerPoint təqdimatı. Tətbiqin bütün R kodu, CSS dizaynı və JavaScript funksiyaları **bir `FP_Receipts_Shiny.R` faylındadır**.

## Portfolio overview

A retail analytics case study built with **R, Shiny, data.table and Plotly**, covering **10,000,909 receipt line items**. It combines exploratory analysis, data-quality diagnostics, time-series forecasting, scenario modelling and an executive presentation.

**Skills demonstrated:** preparing large datasets, repairing text encoding, normalising product/POS names, designing interactive dashboards, validating forecasts with a chronological holdout, and communicating analytical limitations.

**Selected findings:** the default adjusted sales base contains **9,992,904 line items** and **AZN 55.01 million** in sales value. Product mapping covers approximately **1.32%** of rows, which limits category and profit conclusions. Only **24 of 43 calendar days** meet the source-wide normal-volume criterion; forecasts are presented as conditional estimates.

The original Rmd/HTML report is retained as the analytical reference. The Shiny application implements the interactive workflow in a single `.R` file; the presentation summarises the analysis in 21 slides.

![FP Receipts tətbiqinin görünüşü](assets/preview.png)

## Layihənin tərkibi

| Fayl | Təyinatı |
| --- | --- |
| [`FP_Receipts_Shiny.R`](FP_Receipts_Shiny.R) | Tək fayldan işləyən interaktiv Shiny tətbiqi |
| [`presentation/FP_Receipts_Teqdimat.pptx`](presentation/FP_Receipts_Teqdimat.pptx) | 21 slayddan ibarət təqdimat |
| [`docs/DA_Yekun_Layihe_Ramin1.Rmd`](docs/DA_Yekun_Layihe_Ramin1.Rmd) | Verilmiş ilkin analiz mənbəyi |
| [`docs/DA_Yekun_Layihe_Ramin1.html`](docs/DA_Yekun_Layihe_Ramin1.html) | İlkin analizin hazır HTML hesabatı |
| [`data/manifest.json`](data/manifest.json) | Məlumat fayllarının ölçüləri və SHA-256 yoxlama izləri |

## İşə salmaq

R **4.1 və ya daha yeni versiya** istifadə edin. RStudio-da işlətmək də mümkündür.

### 1. Layihəni və məlumatı endirin

Layihəni klonlayın və ya **Code → Download ZIP** seçin. İki RDS faylı [v1.0.0 buraxılışının Assets bölməsindədir](https://github.com/Ahmadzadaa/FP-Receipts/releases/tag/v1.0.0).

`fp_receipts.rds` və `fp_map.rds` fayllarını `.R` faylı ilə eyni qovluğa qoyun:

```text
FP-Receipts/
├── FP_Receipts_Shiny.R
├── fp_receipts.rds
├── fp_map.rds
├── docs/
└── presentation/
```

GitHub CLI ilə alternativ:

```sh
gh repo clone Ahmadzadaa/FP-Receipts
cd FP-Receipts
gh release download v1.0.0 --repo Ahmadzadaa/FP-Receipts --pattern '*.rds'
```

221 MiB-lıq `fp_receipts.rds` GitHub-un [100 MiB adi fayl limitini](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github) keçdiyinə görə məlumatlar Git tarixçəsində deyil, Release Assets daxilində saxlanılır. `Download ZIP` RDS fayllarını daxil etmir; onları buraxılışdan ayrıca endirin.

### 2. R paketlərini quraşdırın

R konsolunda bir dəfə:

```r
install.packages(c(
  "shiny", "bslib", "plotly", "DT", "data.table",
  "stringr", "stringi", "htmltools", "jsonlite", "digest"
))
```

### 3. Tətbiqi açın

RStudio-da `FP_Receipts_Shiny.R` faylını açıb **Source** düyməsini basın. Və ya layihə qovluğunda R konsolunda:

```r
source("FP_Receipts_Shiny.R", encoding = "UTF-8")
```

Terminaldan:

```sh
Rscript FP_Receipts_Shiny.R
```

Tətbiq yerli brauzerdə açılır. İlk açılış 10 milyon sətrin hazırlanmasına görə daha uzun çəkə bilər; sonrakı açılışlar R istifadəçisinin keş qovluğundan istifadə edir. Orijinal RDS faylları yalnız oxunur. Serveri dayandırmaq üçün RStudio-da **Stop**, terminalda **Ctrl+C** basın.

Məlumat başqa qovluqdadırsa, Source-dan əvvəl:

```r
Sys.setenv(FP_RECEIPTS_DATA_DIR = "/tam/yol/melumat_qovlugu")
```

Portu seçmək üçün `FP_SHINY_PORT`, avtomatik brauzeri söndürmək üçün `FP_OPEN_BROWSER=0`, keş yerini dəyişmək üçün `FP_RECEIPTS_CACHE_DIR` istifadə oluna bilər. Server `127.0.0.1` ünvanında işləyir. GitHub repoda kodu saxlayır; Shiny-ni işlətmək üçün R prosesi lazımdır.

## Analiz bölmələri

1. **İcmal:** gəlir və həcm KPI-ları, günlük dinamika, həftə günləri və əvvəlki dövrlə müqayisə.
2. **Satış strukturu:** qiymət aralıqları, ədəd/çəki bölgüsü, paylanma və məhsul xəritəsi.
3. **POS və məhsullar:** reytinqlər, Pareto, axtarış, obyekt müqayisəsi və kliklə profil.
4. **Anomaliyalar:** dəyişən hədlər, günlük keyfiyyət siqnalları və diaqnostik cədvəl.
5. **Proqnoz və fərziyyələr:** dörd model, xronoloji test, MAE/RMSE/MAPE/WAPE, 80%/95% şərti intervallar.
6. **Ssenari laboratoriyası:** qiymət, həcm və marja fərziyyələri; həssaslıq xəritəsi.
7. **Məlumat araşdırıcısı:** axtarış, sıralama və seçilmiş sətir limitli cədvəl.
8. **Metodologiya:** hesablama qaydaları, mənbə izləri və analizin məhdudiyyətləri.

Tarix, POS, məhsul, kateqoriya, satış növü, gün keyfiyyəti və qiymət filtrləri mövcuddur. **Tətbiq et** və ya **Ctrl/Cmd+Enter** ilə filtrləri tətbiq edin. Tünd görünüş, brauzerdə saxlanan filtr görünüşü, qrafik miqyaslama, CSV/JSON və dörd əsas hissəli HTML hesabat ixracı daxildir.

## Hesablamaları necə şərh etməli

- Mənbə dövrü: **19 aprel – 31 may 2024**, **10 000 909 məhsul sətri**. POS adı unikal mağaza/filial identifikatoru deyil.
- Standartda ilkin hesabatın `qnt − 1` və `unit_price − 1` fərziyyəsi tətbiq olunur; mənbə sisteminin təsdiqi ayrıca lazımdır. Əlavə filtrlərdən bunu söndürmək mümkündür.
- Avans və kredit ödənişləri standart satış bazasından çıxarılıb: **9 992 904 sətir**, **55 011 469,69 AZN**.
- Məhsul xəritəsinin əhatəsi təxminən **1,32%**-dir. Mənfəət yalnız məlum marjalar üçün hesablanan şərti göstəricidir.
- Təqvimdə 43 günün 40-da məlumat var. Mənbədə olmayan günlər sıfır satış kimi qəbul edilmir.
- Proqnoz qısa və qeyri-bərabər əhatəli dövrə əsaslanır; ssenarilər tələb elastikliyini modelləşdirmir.
- Araşdırıcıdakı sətir nömrəsi orijinal RDS-dəki mövqedir; `rec_id` deyil. Cədvəl yığcamlaşdırılmış analitik görünüşdür.
- İlkin Rmd faylı dəyişdirilməyib və özündə əvvəlki müəllifin Windows fayl yollarını saxlayır. Hazır nəticəni oxumaq üçün HTML hesabatından istifadə edin; Shiny tətbiqi həmin Rmd-ni işlətməyə ehtiyac duymur.

## Məlumatın yoxlanması

RDS faylları endirildikdən sonra macOS/Linux-da layihə qovluğunda:

```sh
shasum -a 256 -c data/SHA256SUMS
```

Tətbiq üçün filtrlər, boş nəticə, xam/düzəlişli yekunlar, 12 qrafik, proqnoz və ssenari, HTML hesabatı və CSV ixracları yerli mühitdə yoxlanılıb. Tək `.R` faylının ayrıca qovluqdan açılması da sınaqdan keçirilib.
