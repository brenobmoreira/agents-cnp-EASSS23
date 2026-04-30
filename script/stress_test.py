import os
import subprocess
import time
import csv
import signal
import psutil
import re
from pathlib import Path


baterias = [
    # Bateria 1: O Gargalo de Processamento (Estressando m - Base de Crenças)
    {"bateria": 1, "n": 1, "m": 5, "i": 1},
    {"bateria": 1, "n": 1, "m": 15, "i": 1},
    {"bateria": 1, "n": 1, "m": 30, "i": 1},
    {"bateria": 1, "n": 1, "m": 50, "i": 1},
    
    # Bateria 2: Concorrência de Intenções (Estressando i - Limite BDI)
    {"bateria": 2, "n": 5, "m": 20, "i": 1},   
    {"bateria": 2, "n": 5, "m": 20, "i": 3},   
    {"bateria": 2, "n": 5, "m": 20, "i": 5},   
    {"bateria": 2, "n": 5, "m": 20, "i": 8},   
    {"bateria": 2, "n": 5, "m": 20, "i": 10},  
    
    # Bateria 3: Saturação da Rede (Estressando n - Broadcast FIPA)
    {"bateria": 3, "n": 10, "m": 10, "i": 2},
    {"bateria": 3, "n": 50, "m": 10, "i": 2},
    {"bateria": 3, "n": 100, "m": 10, "i": 2},
    {"bateria": 3, "n": 200, "m": 10, "i": 2}, 
    
    # Bateria 4: O Caos Total (O Limite da Máquina)
    {"bateria": 4, "n": 200, "m": 50, "i": 10} 
]

RAIZ_PROJETO = Path(__file__).resolve().parent.parent
ARQUIVO_JCM = RAIZ_PROJETO / "main.jcm"
GRADLEW = RAIZ_PROJETO / "gradlew"
ARQUIVO_CSV = "result.csv"

def gerar_jcm(n, m, i):
    conteudo = f"""mas main {{
    agent gerente : initiator.asl {{
        instances: {n}
        beliefs: num_servicos({i})
    }}
    agent operario : participant.asl {{
        instances: {m}
    }}
}}"""
    with open(ARQUIVO_JCM, "w") as f:
        f.write(conteudo)

def rodar_teste(config):
    bateria, n, m, i = config["bateria"], config["n"], config["m"], config["i"]
    leiloes_esperados = n * i
    print(f"\n Iniciando Bateria {bateria} | n={n}, m={m}, i={i}")
    
    gerar_jcm(n, m, i)
    
    processo = subprocess.Popen(
        [str(GRADLEW), "--no-daemon", "--console=plain"], 
        stdout=subprocess.PIPE, 
        stderr=subprocess.STDOUT,
        text=True,
        cwd=RAIZ_PROJETO,
        preexec_fn=os.setsid 
    )

    # Variáveis inicializadas corretamente
    leiloes_concluidos = 0
    total_mensagens_perdidas = 0
    soma_tempo_bdi = 0
    soma_tempo_total = 0

    cpu_max = 0
    ram_max = 0
    
    start_time = time.time()
    timeout = 40

    try:
        # Atrela o psutil ao PID do Java
        pid = processo.pid
        ps_proc = psutil.Process(pid)
        
        while True:
            linha = processo.stdout.readline()

            ## DEBUG
            if linha.strip(): print(f"   [RAW]: {linha.strip()}")
            
            # Condição para não travar se o processo Java "morrer" antes de terminar
            if not linha and processo.poll() is not None:
                break
                
            # Exibe erros graves do JaCaMo no console do Python
            linha_lower = linha.lower()
            if "error" in linha_lower or "exception" in linha_lower or "failed" in linha_lower:
                print(f"   ❌ [ERRO JACAMO]: {linha.strip()}")

            # Monitora hardware a cada iteração de forma segura
            try:
                cpu = ps_proc.cpu_percent(interval=None)
                ram = ps_proc.memory_info().rss / (1024 * 1024) # Converte pra MB
                if cpu > cpu_max: cpu_max = cpu
                if ram > ram_max: ram_max = ram
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass # Ignora se o processo Java já tiver morrido

            # Leitura das métricas do Jason
            if "METRICA_CNP;" in linha and "<-" not in linha:
                parte_relevante = linha[linha.find("METRICA_CNP;"):]
                dados = parte_relevante.strip().split(";")
                # dados = ["METRICA_CNP", "servico_x", "RespostasRecebidas", "TempoBDI", "TempoTotal"]
                
                respostas_recebidas = int(dados[2])
                tempo_bdi = float(dados[3])
                tempo_total = float(dados[4])
                
                # 1. CÁLCULO DE PERDA FIPA: Eram esperadas 'm' respostas. Chegaram quantas?
                mensagens_perdidas = m - respostas_recebidas
                total_mensagens_perdidas += mensagens_perdidas
                
                soma_tempo_bdi += tempo_bdi
                soma_tempo_total += tempo_total
                leiloes_concluidos += 1
                
                print(f"   ✅ Leilão {leiloes_concluidos}/{leiloes_esperados} | Perdas FIPA: {mensagens_perdidas} msgs | BDI Tempo: {tempo_bdi}ms")

            # Verifica se atingiu a meta de leilões
            if leiloes_concluidos >= leiloes_esperados:
                break
            
            # Verifica se estourou o timeout
            if time.time() - start_time > timeout:
                print("   ⚠️ TIMEOUT: O sistema demorou demais e cortou os leilões pendentes.")
                break
                
    finally:
        os.killpg(os.getpgid(processo.pid), signal.SIGTERM)
        time.sleep(2)
        
    volume_mensagens_geradas = leiloes_concluidos * (1 + m + 1 + (m - 1)) if leiloes_concluidos > 0 else 0
    media_bdi = soma_tempo_bdi / leiloes_concluidos if leiloes_concluidos > 0 else 0
    media_total = soma_tempo_total / leiloes_concluidos if leiloes_concluidos > 0 else 0
    taxa_sucesso = (leiloes_concluidos / leiloes_esperados) * 100 if leiloes_esperados > 0 else 0
    
    print(f"📊 RESULTADO BATERIA {bateria}:")
    print(f"   -> Volume FIPA Gerado: {volume_mensagens_geradas} mensagens")
    print(f"   -> Mensagens FIPA Dropadas: {total_mensagens_perdidas}")
    print(f"   -> Gargalo BDI Médio (.findall): {media_bdi:.1f} ms")
    print(f"   -> Throughput Total Médio: {media_total:.1f} ms")
    
    return [bateria, n, m, i, leiloes_esperados, leiloes_concluidos, taxa_sucesso, volume_mensagens_geradas, total_mensagens_perdidas, media_bdi, media_total, cpu_max, ram_max]

if __name__ == "__main__":
    print("Iniciando avaliação acadêmica COMPLETA (FIPA + BDI + Hardware)...")
    
    with open(ARQUIVO_CSV, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["Bateria", "n_Gerentes", "m_Operarios", "i_Servicos", "Leiloes_Esperados", "Leiloes_Fechados", "Sucesso(%)", "Volume_Msgs_FIPA", "Drop_Msgs_FIPA", "Gargalo_BDI(ms)", "Throughput_Total(ms)", "CPU_Max(%)", "RAM_Max(MB)"])
        
        for config in baterias:
            resultado = rodar_teste(config)
            writer.writerow(resultado)
            f.flush()
            
    print(f"\n Testes finalizados! Resultados salvos em: {ARQUIVO_CSV}")