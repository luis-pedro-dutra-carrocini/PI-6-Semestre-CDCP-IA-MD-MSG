// lib/screens/citizen/c_calls_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/call_model.dart';
import '../../models/theme_model.dart';
import '../../models/user_model.dart';
import './call_activities_screen.dart';
import '../../services/api_client.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => CallsScreenState();
}

class CallsScreenState extends State<CallsScreen> {
  List<CallModel> _filteredCalls = [];
  String _searchQuery = "";

  // ✅ Filtro padrão: PENDENTE (sem "TODOS")
  String _selectedStatus = "PENDENTE";

  final Map<String, String> _statusDisplayNames = {
    "PROCESSAMENTO": "PROCESSAMENTO",
    "PENDENTE": "PENDENTE",
    "ANALISADO": "ANALISADO",
    "ATRIBUIDO": "ATRIBUÍDO",
    "EMATENDIMENTO": "EM ATENDIMENTO",
    "CONCLUIDO": "CONCLUÍDO",
    "FALTAINFORMACAO": "FALTA INFORMAÇÃO",
    "CANCELADO": "CANCELADO",
    "RECUSADO": "RECUSADO",
  };

  // ✅ Sem "TODOS"
  final List<String> _statusOptions = [
    "PROCESSAMENTO",
    "PENDENTE",
    "ANALISADO",
    "ATRIBUIDO",
    "EMATENDIMENTO",
    "CONCLUIDO",
    "FALTAINFORMACAO",
    "CANCELADO",
    "RECUSADO",
  ];

  UserProfile? _currentUser;
  List<CallModel> _calls = [];
  bool _isLoading = true;

  // =============================================
  // ✅ CORES DE STATUS — adaptadas ao tema
  // =============================================
  Color _getStatusColor(String status, ColorScheme cs) {
    // No escuro, usamos cores mais claras/saturadas para contraste
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    switch (status.toUpperCase()) {
      case 'PROCESSAMENTO':
        return dark ? Colors.deepPurple.shade200 : Colors.deepPurple;
      case 'PENDENTE':
        return dark ? Colors.orange.shade300 : Colors.orange;
      case 'ANALISADO':
        return dark ? Colors.blue.shade300 : Colors.blue;
      case 'ATRIBUIDO':
        return dark ? Colors.indigo.shade300 : Colors.indigo;
      case 'EMATENDIMENTO':
        return dark ? Colors.cyan.shade300 : Colors.cyan;
      case 'CONCLUIDO':
        return dark ? Colors.green.shade300 : Colors.green;
      case 'CANCELADO':
        return dark ? Colors.red.shade300 : Colors.red;
      case 'RECUSADO':
        return dark ? Colors.deepOrange.shade300 : Colors.deepOrange;
      case 'FALTAINFORMACAO':
        return dark ? Colors.pink.shade300 : Colors.pink;
      default:
        return cs.onSurfaceVariant;
    }
  }

  // ✅ Fundo "claro" do status, derivado do ColorScheme (funciona no escuro)
  Color _getStatusLightColor(String status, ColorScheme cs) {
    final base = _getStatusColor(status, cs);
    return base.withOpacity(Theme.of(context).brightness == Brightness.dark
        ? 0.15
        : 0.10);
  }

  Color _getStatusBorderColor(String status, ColorScheme cs) {
    final base = _getStatusColor(status, cs);
    return base.withOpacity(0.45);
  }

  @override
  void initState() {
    super.initState();
    loadCalls();
  }

  void _applyFilters() {
    setState(() {
      _filteredCalls = _calls.where((call) {
        final selected = _selectedStatus.replaceAll(" ", "").toUpperCase();
        final currentCallStatus = (call.status)
            .toString()
            .replaceAll(" ", "")
            .toUpperCase();

        final matchesStatus = currentCallStatus == selected;

        final query = _searchQuery.toLowerCase().trim();
        if (query.isEmpty) return matchesStatus;

        final titulo = (call.titulo ?? "").toString().toLowerCase();
        final matchesTitulo = titulo.contains(query);

        final desc = (call.descricaoInicial).toString().toLowerCase();
        final matchesDesc = desc.contains(query);

        final idConcatenado = "${call.n1}-${call.n2}".toLowerCase();
        final matchesId = idConcatenado.contains(query);

        final matchesN1 = call.n1.toString().contains(query);
        final matchesN2 = call.n2.toString().contains(query);

        final matchesSearch =
            matchesTitulo || matchesDesc || matchesId || matchesN1 || matchesN2;

        return matchesStatus && matchesSearch;
      }).toList();
    });
  }

  Future<void> loadCalls() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final themeModel = Provider.of<ThemeModel>(context, listen: false);
      _currentUser = themeModel.currentUser;

      if (_currentUser == null) return;

      final response = await ApiClient.instance.get('/api/chamado');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data.containsKey('data')) {
          final List<dynamic> chamadosJson = data['data'] as List<dynamic>;

          setState(() {
            _calls = chamadosJson.map((json) {
              try {
                return CallModel.fromJson(json);
              } catch (e) {
                final chamadoId = json['ChamadoId'];
                final idString = chamadoId ?? 'desconhecido';
                debugPrint("Erro ao mapear o chamado ID $idString: $e");
                debugPrint("JSON problemático: $json");
                rethrow;
              }
            }).toList();

            _applyFilters();
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar chamados: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ Só navega para atividades se NÃO estiver em PROCESSAMENTO ou PENDENTE
  void _navegarParaAtividades(CallModel call) {
    final status = call.status.toUpperCase();
    if (status == 'PROCESSAMENTO' || status == 'PENDENTE') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'PROCESSAMENTO'
                ? 'Chamado em processamento. Aguarde a análise.'
                : 'Chamado pendente. Aguarde a análise para ver atividades.',
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallActivitiesScreen(
          chamadoId: call.id ?? '',
          chamadoN1: call.n1 ?? 0,
          chamadoN2: call.n2 ?? 0,
        ),
      ),
    );
  }

  Future<void> _cancelCall(String? callId, int? callN1, int? callN2) async {
    if (callId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ID ausente'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text('Deseja cancelar o chamado #$callN1-$callN2?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sim, Cancelar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final response = await ApiClient.instance.patch(
        '/api/chamado/$callId/status',
        body: {'ChamadoStatus': 'CANCELADO'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chamado #$callN1-$callN2 cancelado com sucesso!'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );

        // ✅ Recarrega e aplica o filtro CANCELADO
        await loadCalls();
        if (!mounted) return;
        setState(() {
          _selectedStatus = "CANCELADO";
          _applyFilters();
        });
      } else {
        final data = jsonDecode(response.body);
        final msg =
            data['error'] ?? data['message'] ?? 'Erro ${response.statusCode}';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$msg'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('💥 Falha de rede: $e'),
          backgroundColor: Colors.orange[900],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editCall(CallModel call) async {
    final status = call.status.toUpperCase();

    // ✅ PROCESSAMENTO agora também é editável
    final editavel = status == 'PENDENTE' ||
        status == 'FALTAINFORMACAO' ||
        status == 'PROCESSAMENTO';

    if (!editavel) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Só é possível editar chamados Pendentes, em Processamento ou com Falta de Informação',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final TextEditingController editController = TextEditingController(
      text: call.descricaoInicial,
    );

    final TextEditingController diasController = TextEditingController(
      text: call.diasproblema?.toString() ?? '0',
    );

    final dynamic result = await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Editar Chamado',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: editController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Digite a nova descrição...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelText: 'Descrição',
                        labelStyle: GoogleFonts.inter(fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: diasController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Digite a quantidade de dias...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelText: 'Dias com Problema',
                        labelStyle: GoogleFonts.inter(fontSize: 14),
                        prefixIcon: const Icon(Icons.calendar_today, size: 20),
                        suffixText: 'dias',
                        suffixStyle: GoogleFonts.inter(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          final int? days = int.tryParse(value);
                          if (days != null && days < 0) {
                            diasController.text = '0';
                            diasController.selection =
                                TextSelection.fromPosition(
                              TextPosition(offset: diasController.text.length),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Quantos dias este problema está ocorrendo?',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context, false);
                    }
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (editController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('A descrição não pode estar vazia'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final int? dias = int.tryParse(diasController.text.trim());
                    if (dias == null || dias < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Digite um número válido de dias (mínimo 0)',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (Navigator.canPop(context)) {
                      Navigator.pop(context, {
                        'descricao': editController.text.trim(),
                        'dias': dias,
                        'confirmado': true,
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    minimumSize: const Size(120, 40),
                  ),
                  child: const Text(
                    'Salvar Alterações',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result is Map<String, dynamic> && result['confirmado'] == true) {
      final String novaDescricao = result['descricao'];
      final int novosDias = result['dias'];
      await _atualizarChamado(call, novaDescricao, novosDias);
    }
  }

  Future<void> _atualizarChamado(
    CallModel call,
    String descricao,
    int dias,
  ) async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiClient.instance.put(
        '/api/chamado/${call.id}',
        body: {
          'ChamadoDescricaoInicial': descricao,
          'ChamadoDiasComProblema': dias,
          'PessoaId': _currentUser!.id,
          'UnidadeId': _currentUser!.unidadeId,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chamado atualizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        // ✅ Recarrega e aplica filtro PROCESSAMENTO (backend volta o status)
        await loadCalls();
        if (!mounted) return;
        setState(() {
          _selectedStatus = "PROCESSAMENTO";
          _applyFilters();
        });
      } else {
        final data = jsonDecode(response.body);
        throw data['error'] ?? data['message'] ?? 'Erro ${response.statusCode}';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      // ✅ Fundo derivado do ColorScheme (funciona nos dois temas)
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          'Meus Chamados',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: cs.onSurface,
      ),
      body: Column(
        children: [
          _buildFilterBar(cs),
          Expanded(
            child: RefreshIndicator(
              onRefresh: loadCalls,
              color: cs.primary,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredCalls.isEmpty
                      ? _buildEmptyState(cs)
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                          itemCount: _filteredCalls.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) =>
                              _buildCallCard(context, _filteredCalls[index]),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Icon(Icons.assignment_outlined, size: 70, color: cs.onSurfaceVariant),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Nenhum chamado em $_selectedStatus',
            style: GoogleFonts.inter(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCallCard(BuildContext context, CallModel call) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = _getStatusColor(call.status, cs);
    final statusLightColor = _getStatusLightColor(call.status, cs);
    final statusBorderColor = _getStatusBorderColor(call.status, cs);
    final statusUpper = call.status.toUpperCase();

    // ✅ Editável também em PROCESSAMENTO
    final isEditable = statusUpper == 'PENDENTE' ||
        statusUpper == 'FALTAINFORMACAO' ||
        statusUpper == 'PROCESSAMENTO';

    // ✅ Atividades só disponíveis quando não está em processamento/pendente
    final permiteVerAtividades =
        statusUpper != 'PROCESSAMENTO' && statusUpper != 'PENDENTE';

    return GestureDetector(
      onTap: permiteVerAtividades ? () => _navegarParaAtividades(call) : null,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                Theme.of(context).brightness == Brightness.dark ? 0.4 : 0.04,
              ),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: statusBorderColor,
            width: 1.5,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(18),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'ID #${call.n1}-${call.n2}',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11,
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (permiteVerAtividades)
                                Icon(
                                  Icons.visibility_outlined,
                                  size: 14,
                                  color: cs.onSurfaceVariant,
                                ),
                            ],
                          ),
                          _buildStatusChip(
                            call.status,
                            statusColor,
                            statusLightColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (call.titulo != null && call.titulo!.isNotEmpty)
                        Text(
                          call.titulo!,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                      Text(
                        call.descricaoInicial,
                        style: GoogleFonts.inter(
                          fontSize: call.titulo != null &&
                                  call.titulo!.isNotEmpty
                              ? 12
                              : 15,
                          fontWeight: call.titulo != null &&
                                  call.titulo!.isNotEmpty
                              ? FontWeight.w400
                              : FontWeight.w600,
                          color: call.titulo != null && call.titulo!.isNotEmpty
                              ? cs.onSurfaceVariant
                              : cs.onSurface,
                        ),
                        maxLines:
                            call.titulo != null && call.titulo!.isNotEmpty
                                ? 2
                                : 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (call.status == 'FALTAINFORMACAO' &&
                          call.descricaoFormatada != null &&
                          call.descricaoFormatada!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getStatusLightColor(
                                'FALTAINFORMACAO', cs),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getStatusBorderColor(
                                  'FALTAINFORMACAO', cs),
                            ),
                          ),
                          child: Text(
                            'Falta informação no chamado: ${call.descricaoFormatada}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _getStatusColor('FALTAINFORMACAO', cs),
                            ),
                          ),
                        ),
                      ],
                      if (call.status == 'RECUSADO' &&
                          call.descricaoFormatada != null &&
                          call.descricaoFormatada!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getStatusLightColor('RECUSADO', cs),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getStatusBorderColor('RECUSADO', cs),
                            ),
                          ),
                          child: Text(
                            'Chamado recusado: ${call.descricaoFormatada}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _getStatusColor('RECUSADO', cs),
                            ),
                          ),
                        ),
                      ],
                      if (isEditable) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _editCall(call),
                                child: _buildBtn(
                                  'Editar',
                                  Icons.edit_outlined,
                                  cs.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    _cancelCall(call.id, call.n1, call.n2),
                                child: _buildBtn(
                                  'Cancelar',
                                  Icons.close,
                                  cs.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (!isEditable && permiteVerAtividades) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Toque para ver atividades',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: cs.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: cs.surface,
      child: Column(
        children: [
          TextField(
            onChanged: (value) {
              _searchQuery = value;
              _applyFilters();
            },
            style: TextStyle(color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'Buscar por título, descrição ou ID...',
              hintStyle: TextStyle(color: cs.onSurfaceVariant),
              prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
              filled: true,
              fillColor: cs.surfaceContainerHighest.withOpacity(
                Theme.of(context).brightness == Brightness.dark ? 0.4 : 0.3,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _statusOptions.map((status) {
                final isSelected = _selectedStatus == status;
                final displayName = _statusDisplayNames[status] ?? status;
                final statusColor = _getStatusColor(status, cs);

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? (Theme.of(context).brightness ==
                                    Brightness.dark
                                ? Colors.black
                                : Colors.white)
                            : statusColor,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: statusColor,
                    backgroundColor: statusColor.withOpacity(
                      Theme.of(context).brightness == Brightness.dark
                          ? 0.18
                          : 0.1,
                    ),
                    side: BorderSide(
                      color: statusColor.withOpacity(0.4),
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedStatus = status;
                        _applyFilters();
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, Color color, Color lightColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: lightColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        _statusDisplayNames[status] ?? status,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildBtn(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}