# Analitik metodologiya — Ziyad

Bu sənəd Shiny tətbiqindəki hesablamaları, dörd əsas analiz hissəsini və nəticələri şərh edərkən nəzərə alınmalı məhdudiyyətləri izah edir.

## 1. Deskriptiv təhlil

### Hesablama bazası

Standart parametrlərlə:

```text
qnt_adj        = qnt - 1
unit_price_adj = unit_price - 1
revenue        = qnt_adj × unit_price_adj
```

Bu düzəliş hesabatın qəbul etdiyi fərziyyədir. Daxili paylanma onu araşdırmağa əsas verir, lakin mənbə sisteminin qaydasını sübut etmir. Tətbiqin əlavə filtrlərində xam hesablamaya keçmək olar.

Məhsul adında `AVANS` sözü olan və ya adı `KREDIT` ilə başlayan ödənişlər standart satış bazasından çıxarılır. İstifadəçi onları yenidən daxil edə bilər. `0` miqdar və ya qiymət avtomatik silinmir.

| Hesab bazası | Məbləğ, AZN |
| --- | ---: |
| Xam `qnt × unit_price`, bütün sətrlər | təxminən 144 327 632,29 |
| `-1` düzəlişi, bütün sətrlər | 55 949 921,26 |
| `-1` düzəlişi, avans/kredit çıxarılıb | **55 011 469,69** |

Standart satış bazası 9 992 904 sətirdir. Median sətir gəliri 1,80 AZN, orta sətir gəliri təxminən 5,51 AZN-dir. Bu göstəricilər alış səbətinin orta/median məbləği deyil.

### Adların normallaşdırılması

Məhsul adları üçün bərpa edilə bilən kodlaşdırma xətaları düzəldilir, böyük hərflər və vahid boşluq qaydası tətbiq olunur. POS adlarında hərf və simvol qaydaları ilə təkrarlanan yazılışlar birləşdirilir. Bu əməliyyatlar identifikator yaratmır: eyni ad fərqli filialları, fərqli ad isə eyni məhsulu təmsil edə bilər. `?` ilə itirilmiş hərf hər zaman dəqiq bərpa olunmur.

Məhsul reytinqi normallaşdırılmış adlara, POS reytinqi normallaşdırılmış POS adlarına əsaslanır. Əlavə filtr və reytinq seçimləri ümumi adları çıxara bilər.

### Xəritə və mənfəət

Qoşulma açarı **ay + normallaşdırılmış məhsul adı**-dır. Eyni açarın ilk xəritə sətri saxlanılır. `abs(profit_margin) > 1` marjaları NA edilir. Kateqoriya əhatəsi standart bazada 1,32%-dir.

```text
conditional_profit = revenue × profit_margin
```

Yalnız marjası məlum və etibarlı olan sətrlər bu hesablamaya daxil olur. Xərclər, vergi və uçot tərifi təqdim edilmədiyinə görə göstərici ümumi və ya xalis biznes mənfəəti kimi təqdim edilmir.

## 2. Anomaliyalar və məlumat keyfiyyəti

### Günlərin ilkin statusu

Bütün düzəlişli satış bazasında, məlumatı olan günlərin sətir sayı medianı `M` olsun:

| Qayda | İlkin status |
| --- | --- |
| Sətir sayı `> 2 × M` | Yığılmış data |
| Sətir sayı `< 0,5 × M` | Natamam data |
| Digər məlumatı olan günlər | Normal |
| Mənbədə həmin tarix yoxdur | Data yoxdur |

Nəticə: 24 normal, 15 aşağı həcmli, 1 yüksək həcmli gün. 28–30 may tarixlərinin məlumatı yoxdur. 19 aprel yüksək həcmli gündür. Etiketlər qeyri-adi həcmi göstərir; gecikmiş yükləmə və ya itki səbəbini özlüyündə sübut etmir.

Anomaliya ekranında istifadəçinin dəyişdirdiyi hədlər **cari filtr kəsimi üçün əlavə siqnal** yaradır. Bunlar mənbənin bütün bazadan alınmış ilkin statusunu dəyişmir. Proqnozdakı “Yalnız normal günlər” mənbə statusuna əsaslanır.

### İtkin tarix və sıfır satış fərqi

Mənbədə ümumiyyətlə olmayan gün sıfır gəlir kimi daxil edilmir. Mənbədə olan, lakin cari filtrə uyğun sətri olmayan gün isə həmin kəsimdə sıfır ola bilər. Bu fərq orta günlük gəlir və proqnoz üçün vacibdir.

### Digər yoxlamalar

Xam sütunlarda NA yoxdur. Buna baxmayaraq ümumi POS/məhsul adları, kodlaşdırma problemləri, çox böyük qiymət/miqdarlar və xəritədəki marjalar ayrıca qiymətləndirilir. Bir dəyərin böyük olması onu avtomatik səhv etmir.

## 3. Proqnoz və fərziyyələr

### Xronoloji test

Standart kəsimdə “Yalnız normal günlər” aktivdir. 24 normal gün tarixə görə sıralanır, son 5 gün testə, əvvəlki 19 gün təlimə ayrılır. Standart test tarixləri 20–24 may 2024-dür və hamısı iş günüdür.

Test gəlirləri modelin təlimində istifadə olunmur. Keyfiyyət sinifləri isə əvvəlcədən bütün mənbədən alınmış diaqnostik təsnifatdır. Buna görə bu test əvvəlcədən keyfiyyət seçimi edilmiş tarixi qiymətləndirmədir; tam canlı sistemin geriyə doğru simulyasiyası kimi qəbul olunmamalıdır.

| Model | Test proqnozunun qurulması |
| --- | --- |
| Reqressiya | `daily_revenue ~ weekend + trend`; təlimdə dəyişən olmayan termin buraxılır |
| Sadə orta | Bütün test günləri üçün təlim gəlirinin ortası |
| Son gün | Bütün test günləri üçün son təlim gününün gəliri |
| Həftə gününün ortası | Təlimdə eyni həftə gününün ortası; həmin gün yoxdursa ümumi təlim ortası |

Test üçün 3–10 gün, gələcək sınaq üçün 3–21 gün seçilə bilər. Kifayət qədər gün qalmadıqda tətbiq model qurmaq əvəzinə izah göstərir.

### Xəta göstəriciləri

`y` faktiki gəlir, `p` proqnoz, `n` test günlərinin sayı olsun:

```text
MAE  = mean(abs(y - p))
RMSE = sqrt(mean((y - p)^2))
MAPE = 100 × mean(abs(y - p) / y)
WAPE = 100 × sum(abs(y - p)) / sum(y)
```

MAE və RMSE AZN ilə, MAPE və WAPE faizlə göstərilir. Sıfıra yaxın faktiki gəlir faiz xətalarını böyüdür; MAPE sıfır faktiki gəlirdə müəyyən olunmur. `100 - MAPE` proqnozun düzgün çıxma ehtimalı deyil.

Standart tarixi testdə reqressiyanın MAE-si təxminən 441 614,6 AZN, MAPE-si 38,3%-dir. Sadə orta MAE üzrə daha aşağı xəta verir: 411 575,8 AZN. Beş günlük testdə sadə bazadan yaxşı olmayan modelin biznes planlama üçün üstünlüyü təsdiqlənmir.

### Fərziyyə testi və intervallar

Wilcoxon testi iş günü və həftə sonu gəlir bölgülərinin yeri arasında fərqi araşdırır. Standart 24 normal gün üzrə `p ≈ 0,8783`-dür; 5% səviyyəsində sıfır fərziyyəsi rədd edilmir. Bu, iki gün tipinin eyni olduğunu sübut etmir və birbaşa orta gəlirlərin bərabərliyi testi deyil.

Əmsallar və R² bütün seçilmiş model günləri ilə qurulan tam reqressiyadan göstərilir. Tarixi test xətaları ayrıca 19 günlük təlim modelindən gəlir. Bu bazaları qarışdırmaq olmaz.

Gələcək hissə üçün model bütün seçilmiş tarixçəyə yenidən uyğunlaşdırılır. 80%/95% **proqnoz intervalı** yalnız reqressiya üçün hesablanır. İnterval xətti modelin fərziyyələrinə şərtidir; çatışmayan məlumatı və biznesin bütün risklərini ölçmür.

### Ssenari laboratoriyası

Qiymət dəyişikliyi `p`, həcm dəyişikliyi `v` faizlə verildikdə:

```text
scenario_revenue = base_revenue × (1 + p/100) × (1 + v/100)
```

Məsələn, qiymət +5%, həcm +10% olduqda məbləğ `1,05 × 1,10 = 1,155`, yəni +15,5% olur. Marja dəyişməsi faiz bəndi ilə məlum marjalara əlavə olunur. Şərti mənfəət yalnız marjası məlum olan nümunədə hesablanır. Qiymət dəyişməsinin tələbə təsiri, məhsul qarışığı və xərc reaksiyası ayrıca modelləşdirilmir.

## 4. Xülasə və istifadə sərhədləri

Bu layihə satış strukturu və məlumat keyfiyyətini araşdırmaq, fərziyyələri interaktiv yoxlamaq və sadə proqnoz bazalarını müqayisə etmək üçün hazırlanıb. Təkmilləşdirmə prioritetləri:

1. `-1` düzəlişini ilkin sistemin qaydası ilə təsdiqləmək.
2. Natamam/yüksək həcmli günləri yükləmə jurnalları ilə araşdırmaq.
3. Vahid məhsul kodu, POS/filial kodu və ortaq qəbz identifikatoru əlavə etmək.
4. Məhsul xəritəsinin əhatəsini və dublikatların həllini yaxşılaşdırmaq.
5. Daha uzun fasiləsiz dövrdə xronoloji və təkrarlanan zaman testləri aparmaq.

## Performans və ixrac

10 milyon sətrin mətn sütunları lüğətlərlə yığcamlaşdırılır və hazırlıq keşi saxlanılır. `rec_id` mətn sütunu yığcam keşə köçürülmür. Araşdırıcıda sətir nömrəsi onun əvəzinə göstərilir. Seçilmiş limit yalnız araşdırıcı/export sətrlərinin sayına aiddir; KPI-lar qlobal filtrin bütün uyğun sətrlərindən hesablanır.

Filtr tarixləri, düzəliş seçimi, ödənişlərin daxil edilməsi və digər seçimlər nəticəni dəyişir. Müqayisə üçün eyni filtr bazasını istifadə edin. HTML hesabatı cari kəsimi dörd əsas hissədə saxlayır; CSV ixracı ayrıca seçilmiş nəticə cədvəlinə aiddir.
