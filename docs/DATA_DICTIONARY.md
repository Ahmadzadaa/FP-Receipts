# Məlumat lüğəti — Ziyad

Bu sənəd layihədəki iki xam RDS cədvəlinin faktiki quruluşunu və analitik istifadəsini izah edir. RDS R obyektini, sütun tiplərini və tarix sinfini saxlayan formatdır. Bu faylları `readRDS()` ilə oxumaq lazımdır.

## 1. `fp_receipts.rds`

- **Ölçü:** 10 000 909 sətir × 6 sütun.
- **Fayl ölçüsü:** 231 961 439 bayt.
- **Müşahidə dövrü:** 19 aprel – 31 may 2024.
- **Əhatə:** 43 təqvim gününün 40-da məlumat var.
- **Xam adlar:** 6 569 fərqli POS adı, 675 881 fərqli məhsul adı.
- **NA:** altı sütunun hər birində 0 NA dəyər var. Boş və ümumi mətnlər bununla ölçülmür.
- **Analiz vahidi:** bir məhsul əməliyyatı/sətri.

| Sütun | R sinfi | NA sayı | Mənası və istifadə qaydası |
| --- | --- | --- | --- |
| `pos` | character | 0 | Mənbə POS/obyekt adı. `MARKET` və `APTEK` kimi ümumi adlar və `?` olan mətnlər var. Ad unikal obyekt kodu deyil. |
| `rec_date` | Date | 0 | Gün səviyyəsində əməliyyat tarixi. Saat və dəqiqə verilmir. Günlük trend və ay açarı buradan alınır. |
| `rec_id` | character | 0 | Mənbə identifikatoru. Verilmiş analizdə hər sətirdə unikal olduğu göstərilir; qəbzin digər məhsulları ilə əlaqə üçün ortaq açar təqdim etmir. |
| `product_name` | character | 0 | Məhsulun xam adı. Bir məhsulun müxtəlif yazılışları, ümumi satış etiketləri və zədələnmiş kodlaşdırma ola bilər. SKU/barkod ilə eyni deyil. |
| `qnt` | numeric | 0 | Xam miqdar. Minimum 1, maksimum 300 001. Müxtəlif məhsullar üçün ədəd və kütlə kimi müxtəlif vahidləri qarışdıra bilər. |
| `unit_price` | numeric | 0 | Xam vahid qiymət, AZN. Minimum 1, maksimum 132 301. Analizdə qəbul edilən `-1` düzəlişindən sonra diapazon 0–132 300 olur. |

### Xam məlumatı oxumaq

```r
fp_receipts <- readRDS("fp_receipts.rds")
str(fp_receipts)
head(fp_receipts, 10)
```

İlk 10 sətrə R quraşdırmadan da [CSV nümunəsində](../data/fp_receipts_preview.csv) baxmaq olar. Nümunə xam dəyərləri saxlayır; `-1` düzəlişi və ad normallaşdırması tətbiq edilməyib.

### Nələri hesablamaq olar?

Günlük gəlir, sətir tezliyi, məhsul/POS adı üzrə reytinq, qiymət bölgüsü və məlumat keyfiyyəti göstəriciləri hesablana bilər. Müştəri identifikatoru, etibarlı səbət açarı, filial kodu və məhsul barkodu verilmədiyinə görə müştəri saxlanması, səbət ölçüsü, unikal filial bazar payı və SKU səviyyəsində nəticə çıxarmaq mümkün deyil.

## 2. `fp_map.rds`

- **Ölçü:** 118 118 sətir × 4 sütun.
- **Fayl ölçüsü:** 2 168 558 bayt.
- **Aylar:** 202403, 202404, 202405.
- **Kateqoriyalar:** 70 722 `FOOD`, 47 396 `NON-FOOD` sətri.
- **NA:** dörd sütunun hər birində 0 NA dəyər var.
- **Marja diaqnostikası:** 2 120 sətirdə `abs(profit_margin) > 1` olduğu üçün marja analitik bazada NA edilir.

| Sütun | R sinfi | NA sayı | Mənası və istifadə qaydası |
| --- | --- | --- | --- |
| `period` | numeric | 0 | `YYYYMM` formatında ay açarı. Məsələn, `202404` 2024-cü ilin aprelidir. Say göstəricisi deyil. |
| `product_type` | character | 0 | Mənbə xəritəsinin `FOOD`/`NON-FOOD` etiketi. Etiketlərin düzgünlüyü ayrıca məhsul kataloqu ilə təsdiqlənməyib. |
| `product` | character | 0 | Xəritədəki məhsul adı. Satışdakı `product_name` ilə normallaşdırılmış mətn açarı vasitəsilə tutuşdurulur. |
| `profit_margin` | numeric | 0 | Onluq nisbət formasında marja. `0.21` = 21%, `-0.10` = -10%. Mənfi dəyərlər avtomatik silinmir; mütləq dəyəri 1-dən böyük olanlar istifadə edilmir. |

```r
fp_map <- readRDS("fp_map.rds")
str(fp_map)
head(fp_map, 10)
```

[İlk 10 sətrin CSV nümunəsi](../data/fp_map_preview.csv). Mart xəritəsi faylda mövcuddur, lakin satış məlumatı apreldə başladığı üçün mart sətrləri bu dövrün satışına qoşulmur.

## 3. Cədvəllər necə birləşir?

| Satış tərəfi | Xəritə tərəfi | Hazırlıq |
| --- | --- | --- |
| `rec_date` | `period` | Tarixdən `YYYYMM` ayını çıxarmaq |
| `product_name` | `product` | Kodlaşdırma düzəlişi, böyük hərflərə çevirmə, kənar/çoxlu boşluqların yığılması |

Yalnız məhsul adına görə qoşmaq olmaz: eyni məhsulun müxtəlif aylarda fərqli xəritə sətrləri ola bilər. Tətbiq hər **ay + məhsul açarı** üçün ilk xəritə sətrini saxlayır. Bu qayda çoxalmış birləşmənin qarşısını alır, lakin ziddiyyətli dublikatlar üçün biznes təsdiqli həll deyil.

Qoşulma zamanı satış cədvəlinin sətrləri saxlanılır. Uyğunluq yoxdursa kateqoriya **Bilinmir**, marja isə **NA** olur. Xam xəritədə NA olmaması satışa qoşulduqdan sonra NA yaranmayacağı demək deyil.

Standart satış bazasında:

| Uyğunluq | Sətir sayı |
| --- | ---: |
| FOOD | 130 532 |
| NON-FOOD | 1 366 |
| Bilinmir | 9 861 006 |
| Cəmi | 9 992 904 |

Xəritə əhatəsi **131 898 / 9 992 904 ≈ 1,32%**-dir. Bu kiçik nümunənin kateqoriya və mənfəət nəticələrini bütün satışlara şamil etmək olmaz.

## 4. Analitik törəmə sahələr

| Sahə | Məntiq |
| --- | --- |
| Düzəlişli miqdar | `qnt - 1` |
| Düzəlişli qiymət | `unit_price - 1` |
| Sətir gəliri | Düzəlişli miqdar × düzəlişli qiymət |
| Şərti mənfəət | Sətir gəliri × məlum və etibarlı marja |
| Ay açarı | `as.integer(format(rec_date, "%Y%m"))` |
| Gün tipi | Şənbə/bazar və iş günü |
| Satış olmayan sətir | Normallaşdırılmış adda `AVANS` sözü və ya adın `KREDIT` ilə başlaması |
| Satışın ədəd/çəki ayrımı | Miqdarın tam və ya kəsr olmasına görə diaqnostik ayrım |
| Sətir № | Orijinal RDS-dəki mövqe; `rec_id` deyil |

`-1` düzəlişi verilmiş analizin fərziyyəsidir. İlkin sistemin spesifikasiyası ilə təsdiqlənməyib və tətbiqdə söndürülə bilər. Kəsr miqdar məhsulun çəki ilə satılmasına işarə edir, lakin ayrıca vahid sütunu olmadığı üçün bunu tam təsdiq etmir.

## 5. Faylların saxlanması və yoxlanması

Tam RDS faylları reponun kökündə Git LFS ilə saxlanılır. [Releases](https://github.com/Ahmadzadaa/FP-Receipts/releases/tag/v1.1.0) məlumatı LFS quraşdırmadan endirmək üçün alternativdir. GitHub böyük RDS cədvəlini brauzerdə sətir-sətir göstərmir; sürətli baxış üçün CSV nümunələri, tam interaktiv baxış üçün Shiny araşdırıcısı mövcuddur.

Fayl ölçüləri və SHA-256 izləri [manifest](../data/manifest.json) daxilindədir. Layihə qovluğunda:

```sh
shasum -a 256 -c data/SHA256SUMS
```

Bu yoxlama LFS və Releases-dən alınan faylların eyni məlumat nüsxəsi olduğunu təsdiqləməyə kömək edir.
