// input_handler.v
// Ham girişleri alır, sektirme önlemesi yapar ve işlenmiş çıkışlar üretir.
module input_handler (
    input wire clk, // Genellikle oyun mantığı saatinden daha yavaş bir saat (örn: 1ms periyotlu)
                    // veya oyun mantığı saatiyle çalışıp sayaç kullanılabilir.
                    // Burada clk_game_logic (60Hz) kullanıldığını varsayalım ve sayaçla debouncing yapalım.
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
    output reg p1_move_left_out,
    output reg p1_move_right_out,
    output reg p1_attack_out,
    output reg p1_confirm_out,
    output reg p2_move_left_out,
    output reg p2_move_right_out,
    output reg p2_attack_out,
    output reg game_mode_out     // SW[0]'ın doğrudan (veya filtrelenmiş) değeri
);

    // Sektirme Önleme Parametreleri (60Hz saat için)
    // Örn: 20ms için debounce süresi => 60Hz * 0.020s = 1.2 kare. Yaklaşık 2 kare.
    localparam DEBOUNCE_CLOCKS = 2; // 60Hz'de yaklaşık 33ms

    // Her bir buton için sektirme önleme mantığı
    // Örnek: p1_btn_left için
    reg [1:0] p1_left_history; // Son iki durumu tutar
    reg [$clog2(DEBOUNCE_CLOCKS)-1:0] p1_left_counter;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            p1_left_history <= 2'b00;
            p1_left_counter <= 0;
            p1_move_left_out <= 1'b0;
        end else begin
            p1_left_history <= {p1_left_history[0], p1_btn_left_raw};
            if (p1_left_history == 2'b01) begin // Yükselen kenar (0 -> 1)
                if (p1_left_counter < DEBOUNCE_CLOCKS) begin
                    p1_left_counter <= p1_left_counter + 1;
                end else begin
                    p1_move_left_out <= 1'b1; // Stabil 1
                end
            end else if (p1_left_history == 2'b10) begin // Düşen kenar (1 -> 0)
                 if (p1_left_counter < DEBOUNCE_CLOCKS) begin
                    p1_left_counter <= p1_left_counter + 1;
                end else begin
                    p1_move_left_out <= 1'b0; // Stabil 0
                end
            end else if (p1_left_history == 2'b00 && p1_move_left_out == 1'b1) begin // Stabil 0 ise ve çıkış hala 1 ise
                 p1_left_counter <= 0; // Sayacı sıfırla, bir sonraki düşen kenar için hazır ol
            end else if (p1_left_history == 2'b11 && p1_move_left_out == 1'b0) begin // Stabil 1 ise ve çıkış hala 0 ise
                 p1_left_counter <= 0; // Sayacı sıfırla, bir sonraki yükselen kenar için hazır ol
            end else begin // Stabil durum (00 veya 11)
                p1_left_counter <= 0;
                // p1_move_left_out değişmez
            end
        end
    end

    // Diğer butonlar için benzer sektirme önleme mantığı...
    // p1_move_right_out
    reg [1:0] p1_right_history;
    reg [$clog2(DEBOUNCE_CLOCKS)-1:0] p1_right_counter;
    always @(posedge clk or posedge reset) begin
        if (reset) begin p1_right_history <= 2'b00; p1_right_counter <= 0; p1_move_right_out <= 1'b0;
        end else begin
            p1_right_history <= {p1_right_history[0], p1_btn_right_raw};
            if (p1_right_history == 2'b01) begin if (p1_right_counter < DEBOUNCE_CLOCKS) p1_right_counter <= p1_right_counter + 1; else p1_move_right_out <= 1'b1;
            end else if (p1_right_history == 2'b10) begin if (p1_right_counter < DEBOUNCE_CLOCKS) p1_right_counter <= p1_right_counter + 1; else p1_move_right_out <= 1'b0;
            end else if (p1_right_history == 2'b00 && p1_move_right_out == 1'b1) p1_right_counter <= 0;
            else if (p1_right_history == 2'b11 && p1_move_right_out == 1'b0) p1_right_counter <= 0;
            else p1_right_counter <= 0;
        end
    end

    // p1_attack_out
    reg [1:0] p1_attack_history;
    reg [$clog2(DEBOUNCE_CLOCKS)-1:0] p1_attack_counter;
    always @(posedge clk or posedge reset) begin
        if (reset) begin p1_attack_history <= 2'b00; p1_attack_counter <= 0; p1_attack_out <= 1'b0;
        end else begin
            p1_attack_history <= {p1_attack_history[0], p1_btn_attack_raw};
            if (p1_attack_history == 2'b01) begin if (p1_attack_counter < DEBOUNCE_CLOCKS) p1_attack_counter <= p1_attack_counter + 1; else p1_attack_out <= 1'b1;
            end else if (p1_attack_history == 2'b10) begin if (p1_attack_counter < DEBOUNCE_CLOCKS) p1_attack_counter <= p1_attack_counter + 1; else p1_attack_out <= 1'b0;
            end else if (p1_attack_history == 2'b00 && p1_attack_out == 1'b1) p1_attack_counter <= 0;
            else if (p1_attack_history == 2'b11 && p1_attack_out == 1'b0) p1_attack_counter <= 0;
            else p1_attack_counter <= 0;
        end
    end

    // p1_confirm_out
    reg [1:0] p1_confirm_history;
    reg [$clog2(DEBOUNCE_CLOCKS)-1:0] p1_confirm_counter;
    // Sadece basılma anını yakalamak için (pulse üretimi) - eğer sürekli basılı tutulması istenmiyorsa
    reg p1_confirm_out_prev;
    always @(posedge clk or posedge reset) begin
        if (reset) begin p1_confirm_history <= 2'b00; p1_confirm_counter <= 0; p1_confirm_out <= 1'b0; p1_confirm_out_prev <= 1'b0;
        end else begin
            p1_confirm_out_prev <= p1_confirm_out; // Önceki değeri sakla
            p1_confirm_history <= {p1_confirm_history[0], p1_btn_confirm_raw};
            reg temp_confirm_stable;
            if (p1_confirm_history == 2'b01) begin if (p1_confirm_counter < DEBOUNCE_CLOCKS) p1_confirm_counter <= p1_confirm_counter + 1; else temp_confirm_stable = 1'b1;
            end else if (p1_confirm_history == 2'b10) begin if (p1_confirm_counter < DEBOUNCE_CLOCKS) p1_confirm_counter <= p1_confirm_counter + 1; else temp_confirm_stable = 1'b0;
            end else if (p1_confirm_history == 2'b00 && temp_confirm_stable == 1'b1) p1_confirm_counter <= 0;
            else if (p1_confirm_history == 2'b11 && temp_confirm_stable == 1'b0) p1_confirm_counter <= 0;
            else p1_confirm_counter <= 0;

            if (p1_confirm_counter >= DEBOUNCE_CLOCKS) begin
                 p1_confirm_out <= (p1_left_history == 2'b01 || p1_left_history == 2'b11) ? 1'b1 : 1'b0; // Buton basılıysa 1, değilse 0
            end
            // Eğer sadece tek bir saat vuruşu için pulse isteniyorsa:
            // p1_confirm_out <= (temp_confirm_stable == 1'b1 && p1_confirm_out_prev == 1'b0);
        end
    end


    // p2_move_left_out
    reg [1:0] p2_left_history;
    reg [$clog2(DEBOUNCE_CLOCKS)-1:0] p2_left_counter;
    always @(posedge clk or posedge reset) begin
        if (reset) begin p2_left_history <= 2'b00; p2_left_counter <= 0; p2_move_left_out <= 1'b0;
        end else begin
            p2_left_history <= {p2_left_history[0], p2_btn_left_raw};
            if (p2_left_history == 2'b01) begin if (p2_left_counter < DEBOUNCE_CLOCKS) p2_left_counter <= p2_left_counter + 1; else p2_move_left_out <= 1'b1;
            end else if (p2_left_history == 2'b10) begin if (p2_left_counter < DEBOUNCE_CLOCKS) p2_left_counter <= p2_left_counter + 1; else p2_move_left_out <= 1'b0;
            end else if (p2_left_history == 2'b00 && p2_move_left_out == 1'b1) p2_left_counter <= 0;
            else if (p2_left_history == 2'b11 && p2_move_left_out == 1'b0) p2_left_counter <= 0;
            else p2_left_counter <= 0;
        end
    end

    // p2_move_right_out
    reg [1:0] p2_right_history;
    reg [$clog2(DEBOUNCE_CLOCKS)-1:0] p2_right_counter;
    always @(posedge clk or posedge reset) begin
        if (reset) begin p2_right_history <= 2'b00; p2_right_counter <= 0; p2_move_right_out <= 1'b0;
        end else begin
            p2_right_history <= {p2_right_history[0], p2_btn_right_raw};
            if (p2_right_history == 2'b01) begin if (p2_right_counter < DEBOUNCE_CLOCKS) p2_right_counter <= p2_right_counter + 1; else p2_move_right_out <= 1'b1;
            end else if (p2_right_history == 2'b10) begin if (p2_right_counter < DEBOUNCE_CLOCKS) p2_right_counter <= p2_right_counter + 1; else p2_move_right_out <= 1'b0;
            end else if (p2_right_history == 2'b00 && p2_move_right_out == 1'b1) p2_right_counter <= 0;
            else if (p2_right_history == 2'b11 && p2_move_right_out == 1'b0) p2_right_counter <= 0;
            else p2_right_counter <= 0;
        end
    end

    // p2_attack_out
    reg [1:0] p2_attack_history;
    reg [$clog2(DEBOUNCE_CLOCKS)-1:0] p2_attack_counter;
    always @(posedge clk or posedge reset) begin
        if (reset) begin p2_attack_history <= 2'b00; p2_attack_counter <= 0; p2_attack_out <= 1'b0;
        end else begin
            p2_attack_history <= {p2_attack_history[0], p2_btn_attack_raw};
            if (p2_attack_history == 2'b01) begin if (p2_attack_counter < DEBOUNCE_CLOCKS) p2_attack_counter <= p2_attack_counter + 1; else p2_attack_out <= 1'b1;
            end else if (p2_attack_history == 2'b10) begin if (p2_attack_counter < DEBOUNCE_CLOCKS) p2_attack_counter <= p2_attack_counter + 1; else p2_attack_out <= 1'b0;
            end else if (p2_attack_history == 2'b00 && p2_attack_out == 1'b1) p2_attack_counter <= 0;
            else if (p2_attack_history == 2'b11 && p2_attack_out == 1'b0) p2_attack_counter <= 0;
            else p2_attack_counter <= 0;
        end
    end

    // Oyun modu anahtarı (SW[0]) genellikle doğrudan kullanılır veya çok yavaş değiştiği için
    // karmaşık bir sektirme önlemesine ihtiyaç duymaz. İstenirse basit bir filtre uygulanabilir.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            game_mode_out <= 1'b0; // Varsayılan 2P
        end else begin
            game_mode_out <= sw_game_mode_raw; // Doğrudan ata
        end
    end

endmodule
