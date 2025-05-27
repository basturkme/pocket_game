// input_handler.v
// Ham girişleri alır, sektirme önlemesi yapar ve işlenmiş çıkışlar üretir.
module input_handler (
    input wire clk, // Sektirme önleyici için saat (clk_game_logic - 60Hz varsayılıyor)
    input wire reset,

    // Ham Girişler
    input wire p1_btn_left_raw,
    input wire p1_btn_right_raw,
    input wire p1_btn_attack_raw,
    input wire p1_btn_confirm_raw,
    input wire p2_btn_left_raw,
    input wire p2_btn_right_raw,
    input wire p2_btn_attack_raw,
    input wire sw_game_mode_raw, // SW[0]

    // Sektirme Önlemesi Yapılmış Çıkışlar
    // Artık 'reg' yerine 'wire' olabilirler, çünkü değerleri alt modülden geliyor.
    // Ancak 'output reg' olarak bırakmak da yaygındır, eğer bu modül içinde
    // ek bir atama yapılacaksa (ki burada yapılmıyor).
    // En temizi 'output wire' kullanmaktır.
    output wire p1_move_left_out,
    output wire p1_move_right_out,
    output wire p1_attack_out,
    output wire p1_confirm_out,
    output wire p2_move_left_out,
    output wire p2_move_right_out,
    output wire p2_attack_out,
    output reg game_mode_out     // SW[0]'ın doğrudan (veya filtrelenmiş) değeri
);

    // Her bir buton için sektirme önleyici örnekleri
    debouncer p1_left_debouncer_inst (
        .clk(clk), .reset(reset),
        .raw_in(p1_btn_left_raw), .debounced_out(p1_move_left_out)
    );

    debouncer p1_right_debouncer_inst (
        .clk(clk), .reset(reset),
        .raw_in(p1_btn_right_raw), .debounced_out(p1_move_right_out)
    );

    debouncer p1_attack_debouncer_inst (
        .clk(clk), .reset(reset),
        .raw_in(p1_btn_attack_raw), .debounced_out(p1_attack_out)
    );

    debouncer p1_confirm_debouncer_inst (
        .clk(clk), .reset(reset),
        .raw_in(p1_btn_confirm_raw), .debounced_out(p1_confirm_out)
    );

    debouncer p2_left_debouncer_inst (
        .clk(clk), .reset(reset),
        .raw_in(p2_btn_left_raw), .debounced_out(p2_move_left_out)
    );

    debouncer p2_right_debouncer_inst (
        .clk(clk), .reset(reset),
        .raw_in(p2_btn_right_raw), .debounced_out(p2_move_right_out)
    );

    debouncer p2_attack_debouncer_inst (
        .clk(clk), .reset(reset),
        .raw_in(p2_btn_attack_raw), .debounced_out(p2_attack_out)
    );

    // Oyun modu anahtarı (SW[0]) genellikle doğrudan kullanılır veya
    // çok yavaş değiştiği için karmaşık bir sektirme önlemesine ihtiyaç duymaz.
    // İstenirse basit bir filtre uygulanabilir.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            game_mode_out <= 1'b0; // Varsayılan 2P modu
        end else begin
            game_mode_out <= sw_game_mode_raw; // Doğrudan ata
        end
    end

endmodule