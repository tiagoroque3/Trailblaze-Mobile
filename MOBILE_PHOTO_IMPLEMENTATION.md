# Photo Management Implementation - Trailblaze Mobile App

## Overview
Este documento descreve a implementação da funcionalidade de gestão de fotos na aplicação móvel Trailblaze. A implementação permite upload, visualização e remoção de múltiplas fotos nas atividades tanto para utilizadores PRBO como PO.

## Funcionalidades Implementadas

### 1. Upload de Fotos
- **Câmara**: Tirar fotos diretamente com a câmara do dispositivo
- **Galeria**: Selecionar múltiplas fotos da galeria (máximo 5 por vez)
- **Validação**: Verificação automática de tamanho (máx 10MB por foto)
- **Upload Automático**: As fotos são automaticamente carregadas para o servidor após seleção

### 2. Visualização de Fotos
- **Grid Layout**: Exibição em grelha das fotos numa atividade
- **Visualizador Completo**: Tap na foto para ver em ecrã completo
- **Galeria Navegável**: Deslizar entre fotos na visualização completa
- **Zoom**: Funcionalidade de zoom nas fotos
- **Loading States**: Indicadores de carregamento durante upload

### 3. Gestão de Fotos
- **Remoção Individual**: Eliminar fotos uma a uma
- **Confirmação**: Diálogo de confirmação antes de eliminar
- **Sincronização**: Atualizações em tempo real da lista de fotos
- **Permissões**: Controlo de edição baseado no tipo de utilizador

## Estrutura de Ficheiros

### Novos Ficheiros Criados
```
lib/
├── services/
│   └── photo_service.dart          # Serviço para gestão de fotos
├── widgets/
│   └── photo_gallery_widget.dart   # Widget reutilizável para galeria de fotos
```

### Ficheiros Modificados
```
lib/
├── models/
│   └── activity.dart               # Adicionado método toJson()
├── screens/
│   ├── po_activity_details_screen.dart        # Integração do widget de fotos
│   ├── po_activity_management_screen.dart     # Substituição do sistema antigo
│   └── prbo_activity_details_screen.dart      # Integração do widget de fotos
pubspec.yaml                        # Novas dependências
android/app/src/main/AndroidManifest.xml      # Permissões de câmara e storage
```

## Dependências Adicionadas

### pubspec.yaml
```yaml
# Photo/Image handling
image_picker: ^1.0.4           # Seleção de fotos/câmara
photo_view: ^0.14.0            # Visualizador de fotos com zoom
cached_network_image: ^3.3.0   # Cache de imagens da rede
path_provider: ^2.1.1          # Acesso a diretórios do sistema
permission_handler: ^11.0.1    # Gestão de permissões
```

### Android Permissions
```xml
<!-- Camera and Storage permissions -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />

<!-- Camera feature -->
<uses-feature android:name="android.hardware.camera" android:required="false" />
<uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
```

## Como Usar

### Para Utilizadores PO

#### Tela de Detalhes da Atividade
1. Abrir uma atividade
2. Visualizar fotos existentes na secção "Photos"
3. Tap no ícone "+" para adicionar fotos
4. Escolher entre "Take Photo" ou "Choose from Gallery"
5. As fotos são automaticamente carregadas

#### Tela de Gestão da Atividade
1. Abrir gestão de atividade
2. Ver fotos na secção inferior
3. Adicionar fotos usando o mesmo processo
4. As alterações são guardadas automaticamente

### Para Utilizadores PRBO

#### Tela de Detalhes da Atividade
1. Abrir uma atividade
2. Ver fotos na secção "Photos"
3. Se tiver permissões de edição, pode adicionar/remover fotos
4. Processo idêntico ao PO

## Integração com Backend

### Endpoints Utilizados
- `POST /rest/photos/upload` - Upload de foto individual
- `POST /rest/operations/activity/addinfo` - Adicionar fotos à atividade
- `POST /rest/operations/activity/deletephoto` - Remover foto da atividade

### Fluxo de Upload
1. Utilizador seleciona/tira foto
2. `PhotoService.uploadPhoto()` envia ficheiro para `/rest/photos/upload`
3. Servidor retorna URL da foto
4. `PhotoService.addPhotosToActivity()` associa URL à atividade
5. Interface atualiza lista de fotos

### Fluxo de Remoção
1. Utilizador toca no "X" da foto
2. Confirmação de eliminação
3. `PhotoService.deletePhotoFromActivity()` remove associação
4. Interface atualiza lista de fotos

## Funcionalidades Técnicas

### PhotoService
- Gestão de permissões (câmara/storage)
- Upload com validação de tamanho
- Integração com APIs do backend
- Gestão de erros

### PhotoGalleryWidget
- Widget reutilizável
- Estado reativo
- Suporte para edição condicional
- Interface consistente

### Gestão de Estado
- Atualizações em tempo real
- Callback system para sincronização
- Loading states
- Error handling

## Limitações Atuais
- Máximo 5 fotos por seleção de galeria
- Máximo 10MB por foto
- Suporte apenas para JPG/PNG
- Interface otimizada para Android

## Teste da Funcionalidade

### Cenários de Teste
1. **Upload Câmara**: Tirar foto e verificar carregamento
2. **Upload Galeria**: Selecionar múltiplas fotos
3. **Visualização**: Ver fotos em grid e fullscreen
4. **Remoção**: Eliminar fotos individualmente
5. **Permissões**: Testar com/sem permissões de edição
6. **Validação**: Testar com fotos grandes (>10MB)
7. **Conectividade**: Testar com rede lenta/intermitente

### Verificações
- ✅ Fotos aparecem após upload
- ✅ Zoom funciona no visualizador
- ✅ Remoção atualiza interface
- ✅ Permissões são respeitadas
- ✅ Erros são mostrados adequadamente

## Próximos Passos (Sugestões)
1. Suporte para vídeos
2. Compressão automática de imagens
3. Upload offline com sincronização
4. Filtros e edição básica
5. Backup automático para cloud storage
6. Geolocalização das fotos
