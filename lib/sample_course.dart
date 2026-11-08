// sample_course.dart  (ĐÈ FILE CŨ)
// JSON mẫu hiển thị ở Course library -> "Sample JSON". Có đủ 7 dạng bài + lab + glossary.
const String kSampleJson = r'''
{
  "course_id": "sample_course",
  "course_title": "Sample course (all question types)",
  "chapters": [
    {
      "chapter_id": "chap_demo",
      "chapter_title": "3.0 Infrastructure",
      "nodes": [
        {
          "node_id": "node_demo_all",
          "node_title": "OSPF demo (10 dạng bài)",
          "icon": "router.svg",
          "lesson": [
            {
              "type": "text",
              "title": "Hello và Dead interval của OSPF",
              "body": "Hai router chỉ lên neighbor khi Hello interval và Dead interval khớp nhau.",
              "bullets": [
                "Broadcast và point-to-point: Hello 10s, Dead 40s",
                "NBMA và point-to-multipoint: Hello 30s, Dead 120s",
                "Dead interval mặc định = 4 x Hello"
              ]
            },
            {
              "type": "tip",
              "title": "Mẹo thi",
              "body": "Neighbor không lên thường do Hello/Dead, Area ID, authentication hoặc stub flag không khớp. Kẹt ở ExStart thường do MTU lệch."
            },
            {
              "type": "warn",
              "title": "Đừng nhầm",
              "body": "Router ID không cần giống nhau giữa hai bên, nhưng phải là duy nhất trong domain OSPF."
            }
          ],
          "questions": [
            {
              "type": "multiple_choice",
              "prompt": "Hello interval mặc định của OSPF trên mạng broadcast là bao nhiêu?",
              "options": ["5 giây", "10 giây", "30 giây", "40 giây"],
              "correct_answer": "10 giây",
              "explanation": "Broadcast và point-to-point dùng Hello 10s, Dead 40s. 30s/120s là mặc định của NBMA và point-to-multipoint."
            },
            {
              "type": "multi_select",
              "prompt": "Chọn HAI tham số phải khớp để hai router OSPF thiết lập neighbor trên cùng một link.",
              "options": ["Hello interval", "Router ID", "Area ID", "Process ID", "Interface cost"],
              "correct_answers": ["Hello interval", "Area ID"],
              "explanation": "Hello/Dead và Area ID phải khớp. Router ID phải khác nhau, Process ID chỉ có ý nghĩa cục bộ, cost không cần khớp."
            },
            {
              "type": "reorder",
              "prompt": "Sắp xếp các bước chọn đường BGP theo thứ tự ưu tiên giảm dần:",
              "items": [
                "Weight (cao nhất)",
                "Local Preference (cao nhất)",
                "Locally originated",
                "AS Path (ngắn nhất)"
              ],
              "correct_order": [0, 1, 2, 3],
              "explanation": "Thứ tự: Weight, Local Pref, Locally originated, AS Path, Origin, MED, eBGP trước iBGP."
            },
            {
              "type": "match_pairs",
              "prompt": "Ghép loại LSA OSPF với router/phạm vi tạo ra nó:",
              "pairs": [
                {"left": "LSA Type 1", "right": "Router LSA (trong area)"},
                {"left": "LSA Type 2", "right": "Network LSA (DR tạo)"},
                {"left": "LSA Type 3", "right": "Summary LSA (ABR tạo)"},
                {"left": "LSA Type 5", "right": "External LSA (ASBR tạo)"}
              ],
              "explanation": "Type 1 flood trong area, Type 2 do DR tạo, Type 3 do ABR đưa thông tin liên area, Type 5 do ASBR quảng bá route ngoài."
            },
            {
              "type": "fill_code",
              "prompt": "Chọn từ khóa để ngừng gửi OSPF Hello ra cổng LAN:",
              "template": "router ospf 1\n [BLANK] GigabitEthernet0/1",
              "options": ["passive-interface", "no network", "shutdown", "distribute-list"],
              "correct_answer": "passive-interface",
              "explanation": "passive-interface giữ subnet trong OSPF nhưng không gửi Hello nên không tạo neighbor trên cổng đó."
            },
            {
              "type": "categorize",
              "prompt": "Xếp mỗi thuật ngữ vào đúng giao thức:",
              "pairs": [
                {"left": "LSA", "right": "OSPF"},
                {"left": "DR/BDR", "right": "OSPF"},
                {"left": "Feasible successor", "right": "EIGRP"},
                {"left": "DUAL", "right": "EIGRP"},
                {"left": "AS Path", "right": "BGP"},
                {"left": "Local Preference", "right": "BGP"}
              ],
              "explanation": "LSA và DR/BDR thuộc OSPF; DUAL và feasible successor thuộc EIGRP; AS Path và Local Preference là thuộc tính BGP."
            },
            {
              "type": "show_output",
              "prompt": "Dựa vào output show ip ospf neighbor trên R2, router nào đang là BDR của segment này?",
              "output": "R2#show ip ospf neighbor\n\nNeighbor ID     Pri   State           Dead Time   Address         Interface\n10.1.1.1          1   FULL/BDR        00:00:35    192.168.1.1     GigabitEthernet0/0",
              "options": ["R1 (10.1.1.1)", "R2 (router đang gõ lệnh)", "Cả hai là DR", "Không có BDR"],
              "correct_answer": "R1 (10.1.1.1)",
              "explanation": "Cột State cho biết vai trò của NEIGHBOR: 10.1.1.1 là FULL/BDR nên R1 là BDR. Vì mạng broadcast có DR và BDR, R2 (router đang gõ lệnh) là DR."
            },
            {
              "type": "route_predict",
              "prompt": "Mỗi link ghi cost OSPF. Link R1-R2 đang đứt. Cost từ R1 đến mạng sau R4 bây giờ là bao nhiêu?",
              "topology": {
                "ratio": 0.62,
                "nodes": [
                  {"id": "R1", "label": "R1", "kind": "router", "x": 10, "y": 50},
                  {"id": "R2", "label": "R2", "kind": "router", "x": 45, "y": 18},
                  {"id": "R3", "label": "R3", "kind": "router", "x": 45, "y": 82},
                  {"id": "R4", "label": "R4", "kind": "router", "x": 88, "y": 50}
                ],
                "links": [
                  {"a": "R1", "b": "R2", "label": "10", "down": true},
                  {"a": "R2", "b": "R4", "label": "10"},
                  {"a": "R1", "b": "R3", "label": "20"},
                  {"a": "R3", "b": "R4", "label": "44"}
                ]
              },
              "correct_answer": "64",
              "explanation": "Khi R1-R2 đứt, đường còn lại là R1-R3-R4 với cost 20 + 44 = 64. OSPF cộng cost của các link đi ra (outgoing) dọc đường."
            },
            {
              "type": "topology_drag",
              "prompt": "Kéo các nhãn vào đúng ô trên sơ đồ: vùng giữa hai ABR và router nối ra Internet.",
              "topology": {
                "ratio": 0.5,
                "nodes": [
                  {"id": "A", "label": "R1", "kind": "router", "x": 12, "y": 70},
                  {"id": "B", "label": "R2", "kind": "router", "x": 50, "y": 70},
                  {"id": "C", "label": "R3", "kind": "router", "x": 88, "y": 70},
                  {"id": "I", "label": "Internet", "kind": "cloud", "x": 88, "y": 18}
                ],
                "links": [
                  {"a": "A", "b": "B", "label": ""},
                  {"a": "B", "b": "C", "label": ""},
                  {"a": "C", "b": "I", "label": ""}
                ],
                "slots": [
                  {"id": "s1", "x": 31, "y": 36},
                  {"id": "s2", "x": 69, "y": 36},
                  {"id": "s3", "x": 50, "y": 18}
                ]
              },
              "labels": ["Area 0", "Area 1", "ASBR"],
              "answers": {"s1": "Area 1", "s2": "Area 0", "s3": "ASBR"},
              "explanation": "Mẫu: ô 1 là Area 1, ô 2 là Area 0 (backbone), ô 3 là ASBR vì R3 nối ra ngoài miền OSPF. Hãy sửa theo sơ đồ của bạn."
            },
            {
              "type": "lab",
              "prompt": "Lab: R1 và R2 không lên neighbor OSPF. Tìm lỗi và sửa trên R2.",
              "explanation": "Hello interval của R2 (5s) lệch với R1 (mặc định 10s). Gỡ lệnh ip ospf hello-interval trên Gi0/0 của R2 để về mặc định 10s.",
              "lab": {
                "version": 1,
                "use": ["ospf"],
                "grammar": [],
                "scenario": "R1 và R2 nối với nhau qua link 10.0.0.0/30, cùng chạy OSPF area 0 nhưng chưa thành neighbor. Hãy tìm nguyên nhân và sửa trên R2.",
                "topology": {
                  "links": [
                    {"a": "R1:Gi0/0", "b": "R2:Gi0/0", "label": "10.0.0.0/30"}
                  ]
                },
                "tasks": [
                  {"id": "t1", "text": "Làm cho R1 và R2 thiết lập neighbor OSPF (chỉ sửa R2)"}
                ],
                "max_hints": 2,
                "hints": [
                  "So sánh kết quả show ip ospf interface trên R1 và R2.",
                  "Hello interval của R2 đang khác R1. Gỡ cấu hình hello-interval trên Gi0/0 của R2 để về mặc định."
                ],
                "allow_help": true,
                "devices": [
                  {
                    "id": "R1",
                    "kind": "router",
                    "start_mode": "privileged",
                    "config": [
                      "hostname R1",
                      "interface GigabitEthernet0/0",
                      " ip address 10.0.0.1 255.255.255.252",
                      "router ospf 1",
                      " network 10.0.0.0 0.0.0.3 area 0"
                    ],
                    "show": [
                      {
                        "cmd": "show ip ospf neighbor",
                        "default": "",
                        "variants": [
                          {
                            "when": {
                              "device": "R2",
                              "in": "interface GigabitEthernet0/0",
                              "any": [
                                {"missing": "ip ospf hello-interval *", "in": "interface GigabitEthernet0/0"},
                                {"has": "ip ospf hello-interval 10", "in": "interface GigabitEthernet0/0"}
                              ]
                            },
                            "output": "Neighbor ID     Pri   State           Dead Time   Address         Interface\n10.0.0.2          1   FULL/DR         00:00:36    10.0.0.2        GigabitEthernet0/0"
                          }
                        ]
                      },
                      {
                        "cmd": "show ip ospf interface",
                        "default": "GigabitEthernet0/0 is up, line protocol is up\n  Internet Address 10.0.0.1/30, Area 0\n  Process ID 1, Router ID 10.0.0.1, Network Type BROADCAST, Cost: 1\n  Timer intervals configured, Hello 10, Dead 40, Wait 40, Retransmit 5"
                      }
                    ]
                  },
                  {
                    "id": "R2",
                    "kind": "router",
                    "start_mode": "privileged",
                    "config": [
                      "hostname R2",
                      "interface GigabitEthernet0/0",
                      " ip address 10.0.0.2 255.255.255.252",
                      " ip ospf hello-interval 5",
                      "router ospf 1",
                      " network 10.0.0.0 0.0.0.3 area 0"
                    ],
                    "show": [
                      {
                        "cmd": "show ip ospf neighbor",
                        "default": "",
                        "variants": [
                          {
                            "when": {
                              "in": "interface GigabitEthernet0/0",
                              "any": [
                                {"missing": "ip ospf hello-interval *", "in": "interface GigabitEthernet0/0"},
                                {"has": "ip ospf hello-interval 10", "in": "interface GigabitEthernet0/0"}
                              ]
                            },
                            "output": "Neighbor ID     Pri   State           Dead Time   Address         Interface\n10.0.0.1          1   FULL/BDR        00:00:34    10.0.0.1        GigabitEthernet0/0"
                          }
                        ]
                      },
                      {
                        "cmd": "show ip ospf interface",
                        "default": "GigabitEthernet0/0 is up, line protocol is up\n  Internet Address 10.0.0.2/30, Area 0\n  Process ID 1, Router ID 10.0.0.2, Network Type BROADCAST, Cost: 1\n  Timer intervals configured, Hello 10, Dead 40, Wait 40, Retransmit 5",
                        "variants": [
                          {
                            "when": {
                              "in": "interface GigabitEthernet0/0",
                              "has": "ip ospf hello-interval 5"
                            },
                            "output": "GigabitEthernet0/0 is up, line protocol is up\n  Internet Address 10.0.0.2/30, Area 0\n  Process ID 1, Router ID 10.0.0.2, Network Type BROADCAST, Cost: 1\n  Timer intervals configured, Hello 5, Dead 20, Wait 20, Retransmit 5"
                          }
                        ]
                      }
                    ]
                  }
                ],
                "goals": [
                  {
                    "id": "g1",
                    "task": "t1",
                    "device": "R2",
                    "in": "interface GigabitEthernet0/0",
                    "any": [
                      {"missing": "ip ospf hello-interval *", "in": "interface GigabitEthernet0/0"},
                      {"has": "ip ospf hello-interval 10", "in": "interface GigabitEthernet0/0"}
                    ]
                  }
                ],
                "solution": [
                  {
                    "device": "R2",
                    "commands": [
                      "interface gi0/0",
                      "no ip ospf hello-interval",
                      "end",
                      "copy running-config startup-config"
                    ]
                  }
                ]
              }
            }
          ]
        }
      ]
    }
  ],
  "glossary": [
    {"term": "ABR", "def": "Area Border Router: router nối nhiều area OSPF, tạo LSA Type 3.", "cmd": "show ip ospf border-routers", "tag": "OSPF"},
    {"term": "Hello interval", "def": "Chu kỳ gửi gói Hello của OSPF. Phải khớp giữa hai bên để lên neighbor.", "cmd": "ip ospf hello-interval 10", "tag": "OSPF"},
    {"term": "Local Preference", "def": "Thuộc tính BGP chỉ lan truyền trong iBGP. Giá trị cao hơn được ưu tiên, mặc định 100.", "cmd": "bgp default local-preference 200", "tag": "BGP"}
  ]
}
''';
