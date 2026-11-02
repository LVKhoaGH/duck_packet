/// Template shown in Course library > Sample JSON.
const kSampleJson = r'''{
  "course_id": "encor_350_401",
  "course_title": "CCNP Enterprise ENCOR (350-401)",
  "chapters": [
    {
      "chapter_id": "chap_sample",
      "chapter_title": "3.0 Infrastructure",
      "nodes": [
        {
          "node_id": "node_sample_ospf",
          "node_title": "OSPF cơ bản",
          "icon": "router.svg",
          "lesson": [
            {
              "type": "text",
              "title": "OSPF trong 30 giây",
              "body": "Giao thức link-state, mỗi router tự chạy SPF.",
              "bullets": [
                "AD = 110",
                "Area 0 là backbone",
                "Hello gửi tới 224.0.0.5"
              ]
            },
            {
              "type": "flow",
              "title": "Hai router thành neighbor",
              "steps": [
                {
                  "who": "Router A",
                  "do": "Gửi Hello"
                },
                {
                  "who": "Router B",
                  "do": "Thấy router-ID của mình trong Hello, chuyển sang 2-Way"
                },
                "Trao đổi DBD, LSR, LSU rồi lên Full"
              ]
            },
            {
              "type": "compare",
              "title": "Network type",
              "headers": [
                "Type",
                "DR/BDR",
                "Hello/Dead"
              ],
              "rows": [
                [
                  "Broadcast",
                  "Có",
                  "10/40"
                ],
                [
                  "Point-to-point",
                  "Không",
                  "10/40"
                ]
              ]
            },
            {
              "type": "code",
              "title": "Cấu hình",
              "code": "router ospf 1\n router-id 1.1.1.1\n network 10.0.0.0 0.0.0.255 area 0",
              "note": "Ghi chú nhỏ hiện dưới khối lệnh"
            },
            {
              "type": "tip",
              "title": "Mẹo thi",
              "body": "Priority cao nhất thắng bầu DR, bằng nhau thì router-ID cao nhất."
            },
            {
              "type": "warn",
              "title": "Dễ nhầm",
              "body": "Kẹt ở 2-Way trên mạng broadcast là bình thường với router không phải DR/BDR."
            }
          ],
          "questions": [
            {
              "type": "multiple_choice",
              "prompt": "Địa chỉ multicast router OSPF dùng để gửi Hello là gì?",
              "options": [
                "224.0.0.5",
                "224.0.0.9",
                "224.0.0.10",
                "239.0.0.1"
              ],
              "correct_answer": "224.0.0.5",
              "explanation": "224.0.0.5 là AllSPFRouters. 224.0.0.6 dành cho DR/BDR."
            },
            {
              "type": "fill_code",
              "prompt": "Chọn từ khoá để đưa mạng vào area 0:",
              "template": "router ospf 1\n network 10.0.0.0 0.0.0.255 [BLANK] 0",
              "options": [
                "area",
                "vrf",
                "process",
                "level"
              ],
              "correct_answer": "area",
              "explanation": "Cú pháp: network <ip> <wildcard> area <id>."
            },
            {
              "type": "reorder",
              "prompt": "Sắp xếp trạng thái neighbor OSPF theo thứ tự:",
              "items": [
                "Down",
                "Init",
                "2-Way",
                "ExStart",
                "Exchange",
                "Loading",
                "Full"
              ],
              "correct_order": [
                0,
                1,
                2,
                3,
                4,
                5,
                6
              ],
              "explanation": "Items viết sẵn theo đúng thứ tự, app tự xáo khi hiển thị."
            },
            {
              "type": "match_pairs",
              "prompt": "Ghép loại LSA với nơi tạo ra:",
              "pairs": [
                {
                  "left": "LSA Type 1",
                  "right": "Mọi router"
                },
                {
                  "left": "LSA Type 2",
                  "right": "DR"
                },
                {
                  "left": "LSA Type 3",
                  "right": "ABR"
                },
                {
                  "left": "LSA Type 5",
                  "right": "ASBR"
                }
              ],
              "explanation": "Cặp đúng là left[i] với right[i]. Các right không được trùng nhau."
            },
            {
              "type": "categorize",
              "prompt": "Xếp LSA vào đúng nhóm:",
              "pairs": [
                {
                  "left": "LSA Type 1",
                  "right": "Chỉ trong area"
                },
                {
                  "left": "LSA Type 2",
                  "right": "Chỉ trong area"
                },
                {
                  "left": "LSA Type 3",
                  "right": "Đi qua area khác"
                },
                {
                  "left": "LSA Type 5",
                  "right": "Đi qua area khác"
                }
              ],
              "explanation": "left là thuật ngữ, right là tên nhóm (2 đến 4 nhóm)."
            }
          ]
        }
      ]
    }
  ],
  "glossary": [
    {
      "term": "DR / BDR",
      "def": "Router đại diện và dự phòng trên mạng broadcast.",
      "cmd": "ip ospf priority 100",
      "tag": "OSPF"
    },
    {
      "term": "ABR",
      "def": "Router nối nhiều area OSPF."
    }
  ]
}''';
