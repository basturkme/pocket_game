// clock_divider_functional.v
// Giriş saat frekansını bölen fonksiyonel saat bölücü modülü

module clock_divider_functional #(
    parameter DIVISOR = 10 // Giriş saat frekansının bölüneceği faktör
)(
    input wire clk,        // Giriş saati
    input wire reset,      // Aktif yüksek reset
    output reg clk_out     // Bölünmüş saat çıkışı
);

    // COUNT_MAX_VAL, clk_out'un yarım periyodu için giriş saati döngü sayısını belirler.
    // clk_out'un periyodunun DIVISOR * T_clk_in olması için,
    // her (DIVISOR/2) * T_clk_in'de bir durum değiştirmelidir.
    // Sayaç 0'dan COUNT_MAX_VAL'e kadar sayar.
    localparam COUNT_MAX_VAL = (DIVISOR / 2) - 1;

    // Sayacın genişliğini belirle.
    // Sayaç 0'dan (DIVISOR/2)-1'e kadar değerler alır.
    // Bu, DIVISOR/2 adet farklı değer demektir.
    // Gerekli bit sayısı $clog2(DIVISOR/2)'dir.
    // Eğer DIVISOR=2 ise, DIVISOR/2=1, $clog2(1)=0. Ancak sayacın '0' değerini tutabilmesi için en az 1 bit gerekir.
    // Aşağıdaki ifade bu durumu ele alır: [MSB_index : 0]
    // Eğer $clog2(DIVISOR/2) sonucu 0 ise (DIVISOR=2 durumu), MSB_index 0 olur, yani [0:0].
    // Eğer $clog2(DIVISOR/2) sonucu N > 0 ise, MSB_index N-1 olur, yani [N-1:0].
    reg [$clog2(DIVISOR/2) > 0 ? $clog2(DIVISOR/2)-1 : 0 :0] count;

    // Başlangıç değerleri reset koşulunda ayarlanır.
    // initial begin
    //     clk_out = 1'b0;
    //     // count = 0; // Reset ile zaten yapılıyor
    // end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count <= 0;
            clk_out <= 1'b0;
        end else begin
            if (count == COUNT_MAX_VAL) begin
                count <= 0;
                clk_out <= ~clk_out; // Saat çıkışının durumunu değiştir
            end else begin
                count <= count + 1;
            end
        end
    end

endmodule
