# N05-N06 学習ログ

## 状況とAI利用

2026-10-30、本人のN05-N06実装・検証依頼に基づく先行準備。N03・N04の理解度チェックは対話で完了したが、LETUS提出は本人の希望で後回し。N03・N04のPRはmergeせず、prepare/N04-advection-diffusionから本課題の準備ブランチを作った。進捗記録はN03のまま保つ。以下はAI作成の技術説明であり、本人の予想・考察・採否理由の代筆ではない。N05・N06の理解度チェック・提出・本人レビューは未確認。

## N05：抽出前の基準と依存関係

共通化前の完成コード0398e53105b1ca4b7376239e72582bd142648cae（N04先行準備）から、公式N05.jl baselineを実行して新しい基準を取得した。N04のSELECTED_MODELはlinear。baselineは以前の隔離環境からコピーせず、上書きしない。回帰比較は新しいJuliaプロセスで読み込んだ計算値と行い、読み込み済みの古い定義との混同を避ける。

基準：[baseline.toml](results/N05/baseline.toml)。取得時のSHA-256は36b5a7516be36f73f8aabd71a5004e722a30c98c60946f1ee661b21220eff3e9。git_headとcode_sha256には抽出前の来歴を記録している。これはN03・N04が提出済みという意味ではなく、技術上の完成コードの基準である。

先行実装eda2373を確認し、周期左右添字、線形・Burgers流束、独立バッファ検証、刻み調整、N01〜N04の更新・境界処理を共通パッケージへ移した。各課題のrun.jlは元の引数・既定値・戻り値・境界規約を保つ薄い委譲とし、数値更新を複製して残さない。

例：N02NonlinearAdvection.nonlinear_upwind_step! → ThermofluidExercise.N02.nonlinear_upwind_step! → 共通周期添字・Burgers流束。新配列だけを書き換え、旧配列を保ち、更新した新配列を返す。固定境界は内部更新後に別入口で適用する。

初期条件、実験条件、N04選択、診断、描画は各課題側に残した。N04はmodel等を引数で渡し、共通側からrun.jlの大域変数を参照しない。moduleは名前の範囲、includeはファイル内コードの読み込み、importは既存モジュールの利用を明示する。Project.tomlの名前・UUIDとsrc/ThermofluidExercise.jlがパッケージ入口であり、ScratchのMiniFluxとは独立である。

回帰：[regression.toml](results/N05/regression.toml)。キー・形状・整数・選択モデルを保持し、有限な浮動小数をrtol=1e−12・atol=1e−13で比較する。回帰一致は挙動維持の証拠であり、共通化前からある物理的誤りやテスト対象外の誤りがない証明ではない。基準を抽出後に再生成すると退行を隠すため、最初の基準ハッシュを照合する。

## N06：二次元更新と保存場

領域[0,2)×[0,1)、速度(cx,cy)=(1,0.5)、両方向周期。u[i,j]は(x[i],y[j])を表す。先頭の左隣はその軸の末尾で、角でも両方向の周期添字を別々に用いる。

更新式はu_new[i,j]=u_old[i,j]−Cx×(u_old[i,j]−u_old[im,j])−Cy×(u_old[i,j]−u_old[i,jm])、Cx=cx×dt/dx、Cy=cy×dt/dy。両方向とも同じ旧配列から計算し、合成CFL=Cx+Cy≤1を検証してから書き込む。dt_max=0.8/(cx/dx+cy/dy)。片方向速度0ならその方向の寄与が消え、両方向0なら場は不変となる（安定刻み関数は少なくとも一方が正を要求する）。負速度で風上方向を切り替える方式ではない。

保存時刻は0,0.25,0.5,0.75,1。外側ループで保存区間を選び、fit_timestepで区間長に合う刻みを決め、内側ループで1ステップ更新とバッファ交換を繰り返す。最新場をU[:,:,k]へコピーする。バッファの参照だけを保持すると過去の場も上書きされるため、独立した保存領域が必要。

3格子は40×30、80×60、160×120。解析解は初期関数u0(x−cx×t,y−cy×t)の周期移動。積分はdx×dy×sum(u)、L2誤差はsqrt(sum(abs2,u−exact)/length(u))、L∞は最大絶対誤差、分散は平均からの二乗偏差の平均。

## テストの意味と限界

配布済み必須部分は保持し、非正方の非対称3×4配列の独立した手計算期待値で周期端・角・軸・方向寄与を確認する。定数場、片方向速度0、旧配列不変、alias拒否、合成CFL超過拒否も確認する。

自作保存テストは5×7非対称場u[i,j]=0.3i+0.07j²、dx=0.4、dy=1/7、dt=0.02、cx=0.6、cy=0.2を80ステップ更新する。テスト側の独立した初期積分dx×dy×sum(u)を基準とし、rtol=0・atol=1e−12×max(1,abs(initial_integral))で丸めを許容する。これは厳密な丸め誤差上界ではない。非保存な更新は検出するが、何もしない方式や保存的な誤式は通り得る。

自作収束テストは公式3格子を同じt=1で解析解と比べ、L2誤差の単調減少と両区間の次数0.8〜1.2を要求する。空間1次風上差分の数値拡散による約1次収束を検査する。別の初期値・速度・負速度・全格子の正しさは保証しない。手計算・保存・収束を併用する。

## 段階実行と再解析・再作図

[保存場](results/N06/fields.h5)、[診断](results/N06/summary.toml)、[場の図](results/N06/fields.png)、[保存・誤差](results/N06/diagnostics.png)、[収束](results/N06/convergence.png)、[表示来歴](results/N06/plots.toml)。

速度・格子・初期場を変える場合はsimulateから再計算する。診断項目の追加はanalyzeで保存場を再解析し、色や代表格子だけの変更はplotで再作図する。表示では初期・数値・解析の色範囲を共通に保ち、誤差だけは0を中心とした別の色範囲を使う。

5保存時刻の間の場や極値の発生時刻は、そのHDF5から直接は読み出せない。HDF5の軸順序・座標・単位・条件・ハッシュを確認して解釈し、保存場と現在コードの同一性を根拠なく仮定しない。

## 再現コマンド

```sh
julia --startup-file=no --project=. exercises/N05-N06_common_package_2d_advection/N05.jl baseline  # 抽出前に一度だけ
julia --startup-file=no --project=. exercises/N05-N06_common_package_2d_advection/N05.jl verify
julia --startup-file=no --project=. exercises/N05-N06_common_package_2d_advection/simulate.jl
julia --startup-file=no --project=. exercises/N05-N06_common_package_2d_advection/analyze.jl
GKSwstype=100 julia --startup-file=no --project=. exercises/N05-N06_common_package_2d_advection/plot.jl
julia --startup-file=no --project=. exercises/N05-N06_common_package_2d_advection/tests.jl
julia --startup-file=no --project=. test/runtests.jl
```

baselineは現在すでに存在するため、再実行しない。環境によるキャッシュ書き込み制限を避ける場合は、書き込み可能な一時depotをJULIA_DEPOT_PATHの先頭に置く。数値検証とキャッシュ初期化のメッセージを区別する。確定した実行結果・ハッシュは下へ記録する。

## 出典・本人作業

公式[N05](https://t2lab-it.github.io/thermofluid-exercise-2026/assignments/N05.html)・[N06](https://t2lab-it.github.io/thermofluid-exercise-2026/assignments/N06.html)、学生配布コードd74dda0、先行実装eda2373。コードMIT、公開ログ・学生図CC BY 4.0。第三者画像の転載なし。AIの技術案は共通化の依存方向を保ち、実際の基準・回帰・保存・解析解収束で検証する方針。本人の最終採否・実行前予想・考察は未確認。

N05・N06それぞれの理解度チェック、LETUS提出日・提出済み確認、本人の振り返り・最終レビューは未確認。対話全文を公開リポジトリに含めず、技術実装だけで提出完了とは扱わない。

## 2026-10-30 実測結果

- 共通化前後10,258項目の数値差はすべて0。baselineのSHA-256は取得時と同一。
- N03までの進捗連動回帰は終了コード0。共通199、F02 6、F03-F04 21、N01 26、N02 59、N03 119件成功。F01は既知の1成功・1失敗・1エラーの過去課題警告で、全件無警告成功とはしない。N04単独は135件成功。
- 分散未実装で基本解析を実行しdiagnostics_complete=falseを確認してから、分散を追加して再解析しtrueを確認した。基本診断はscratch/N0506-verification/basic-summary.tomlへ保存。
- fields.h5のSHA-256は基本解析前・分散追加後・再作図後のすべてで `7efb93a1ce81fb97eebf6221af0c739f5ce982d2c0d2d28b6ca95bd4e18a9742`。
- 再作図前後のsummary.tomlのSHA-256は `5e41ae5fc77cca1b385822811864a30155ad76a900267beb73285e9a4f2eecf2` で不変。最初はviridis・[0.4,1.6]、最後はcividis・[0.3,1.7]で作図し、plots.tomlの入力hashと表示条件も照合した。
- L2誤差は40×30で0.04586691138478507、80×60で0.02406462411492619、160×120で0.012332831539922874。両区間の次数は0.9305398727322467、0.9644098174384694。
- 保存5時刻での積分変化の最大絶対値は粗格子2.220446049250313e−16、中・細格子0。最終分散は粗0.04830334553165218、中0.05810957283257867、細0.06376655312125709。数値拡散が粗格子で強い傾向と整合する。
- 再生成summaryの全診断値を保存済み公式n06-referenceとrtol=1e−7・atol=2e−10で比較し成功。入力HDF5ハッシュは生成物固有のため基準値との一致を要求せず、実ファイルとの一致と段階間不変を独立に検証した。
- 一時depotの初期プリコンパイルではHTTPのソケットbindがsandboxで拒否された旨の通知があったが、プリコンパイル側で無視され、数値計算・回帰・保存処理は終了コード0。
