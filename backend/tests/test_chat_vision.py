import io
from types import SimpleNamespace as NS
from unittest.mock import patch, Mock
import pytest
from PIL import Image
from fastapi import HTTPException
from app.services import chat_vision as v
from app.services import glm_extraction as g


def photo():
    out=io.BytesIO();Image.new('RGB',(200,100),'red').save(out,format='JPEG');return out.getvalue()

@pytest.mark.parametrize('path',['foreign/a.jpg','actor/../foreign.jpg','actor/%2e%2e/foreign.jpg','https://evil.test/a.jpg'])
def test_retained_image_cannot_fetch_foreign_or_external_resource(path):
    with patch('app.services.supabase_client.get_supabase_raw') as db:
        with pytest.raises(HTTPException):v.retained_image('actor',{'mode':'chat','source_path':path})
    db.assert_not_called()

def test_retained_image_loads_owned_bytes_not_expired_url():
    bucket=Mock();bucket.download.return_value=photo()
    with patch('app.services.supabase_client.get_supabase_raw') as db:
        db.return_value.storage.from_.return_value=bucket
        result=v.retained_image('actor',{'mode':'chat','source_path':'actor/ask-test.jpg','source_url':'https://expired.test'})
    bucket.download.assert_called_once_with('actor/ask-test.jpg')
    assert result['image_url']['url'].startswith('data:image/jpeg;base64,')

@pytest.mark.parametrize('box',[[-1,0,100,100],[0,0,1001,100],[100,0,50,100],[0,50,100,50]])
def test_grounding_rejects_invalid_boxes(box):
    with pytest.raises(ValueError):g.crops(photo(),[g.Box(label='tool',box=box)])

def test_grounding_crops_actual_pixels_and_removes_near_duplicate():
    candidates=[g.Box(label='tool',box=[0,0,500,1000]),g.Box(label='duplicate',box=[0,0,500,1000])]
    result=g.crops(photo(),candidates)
    assert len(result)==1
    assert Image.open(io.BytesIO(result[0][1])).size==(100,100)

def test_grounding_refines_crops_and_retains_review_uncertainty():
    ground=g.Grounding(items=[g.Box(label='tool',box=[0,0,500,1000])],partial=True)
    identified=g.Identities(items=[g.Identity(index=0,name='Pliers',category='Tools',uncertainty='Model number is not visible.')])
    upload=Mock(return_value=NS(path='actor/crop.jpg',url='https://image.test/crop'))
    with patch.object(g,'_json',side_effect=[ground,identified]) as model:
        result=g.extract(photo(),'actor','https://image.test/original',upload=upload)
    assert len(model.call_args_list[1].args[1])==1
    assert result['summary']['partial'] is True
    item=result['items'][0]
    assert item['scan_evidence']['needs_review'] is True
    assert item['source_frame_url']=='https://image.test/original'
    assert item['part_number'] is None


def test_invalid_refinement_cannot_upload_or_save():
    ground=g.Grounding(items=[g.Box(label='tool',box=[0,0,500,1000])],partial=False)
    upload=Mock()
    with patch.object(g,'_json',side_effect=[ground,g.Identities(items=[])]):
        with pytest.raises(ValueError):g.extract(photo(),'actor',None,upload=upload)
    upload.assert_not_called()


def test_grounding_validates_final_json_without_inventory_tools():
    answer=NS(choices=[NS(message=NS(content='{"items": [], "partial": false}'))])
    with patch.object(g,'gateway_completion',return_value=answer) as gateway:
        result=g._json('Find objects',[photo()],g.Grounding)
    assert result.items==[]
    args=gateway.call_args.kwargs
    assert 'tools' not in args
    assert 'schema' in args['messages'][1]['content'][0]['text']


def test_grounding_invalid_output_retries_once_then_fails():
    with patch.object(g,'gateway_completion',return_value=NS(choices=[NS(message=NS(content='Done'))])) as gateway:
        with pytest.raises(ValueError):g._json('Find objects',[photo()],g.Grounding)
    assert gateway.call_count==2


def test_retention_uses_schema_compatible_hidden_assistant_receipt():
    photo={'mode':'chat','source_path':'actor/ask.jpg'}
    with patch('app.services.world_chat.save_answer') as save:
        v.retain('actor','personal','cid','turn',photo)
    save.assert_called_once_with('actor','personal','cid','',{
        'attachment_receipt':True,'turn_id':'turn','chat_photo':photo,
    })
