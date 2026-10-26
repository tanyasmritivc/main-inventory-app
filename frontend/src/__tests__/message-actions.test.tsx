/** @jest-environment jsdom */
import {useState} from 'react';
import {render, screen, fireEvent, waitFor} from '@testing-library/react';
import {MessageActions, copyMessage, type ResponseRating} from '@/components/site/message-actions';
import {accountRequest} from '@/lib/account-request';
jest.mock('@/lib/account-request',()=>({accountRequest:jest.fn()}));
const api=jest.mocked(accountRequest);
const saved:ResponseRating={id:'f',message_id:'exact-message',rating:1,revision:1,reason:null,comment:null,updated_at:'2026-10-25T20:00:00Z'};
function Harness({initial}:{initial?:ResponseRating}) { const [rating,setRating]=useState(initial);return <MessageActions accountId="actor" messageId="exact-message" role="assistant" content="Answer" timestamp="2026-10-25T20:00:00Z" rating={rating} onRating={setRating} onRetry={()=>{}}/>; }
beforeEach(()=>jest.resetAllMocks());
it('waits for a confirmed exact-message receipt and locks repeated taps',async()=>{
 let finish!:(v:unknown)=>void;api.mockImplementation(()=>new Promise(resolve=>{finish=resolve;}) as never);
 render(<Harness/>);const up=screen.getByLabelText('Good response');fireEvent.click(up);fireEvent.click(up);
 expect(up.getAttribute('aria-pressed')).toBe('false');expect(api).toHaveBeenCalledTimes(1);
 expect(api).toHaveBeenCalledWith('actor','/response-feedback/exact-message',expect.objectContaining({body:{rating:1,reason:null,comment:null,expected_revision:0}}));
 finish(saved);await waitFor(()=>expect(up.getAttribute('aria-pressed')).toBe('true'));
});
it('does not select failed feedback and allows retry',async()=>{
 api.mockRejectedValueOnce(new Error()).mockResolvedValueOnce(saved);render(<Harness/>);
 fireEvent.click(screen.getByLabelText('Good response'));await screen.findByRole('alert');
 expect(screen.getByLabelText('Good response').getAttribute('aria-pressed')).toBe('false');
 fireEvent.click(screen.getByLabelText('Good response'));await waitFor(()=>expect(screen.getByLabelText('Good response').getAttribute('aria-pressed')).toBe('true'));
});
it('restores a saved selection and updates negative reasons using revision',async()=>{
 api.mockResolvedValueOnce({...saved,rating:-1,revision:2}).mockResolvedValueOnce({...saved,rating:-1,reason:'incomplete',comment:'Missing one',revision:3});
 render(<Harness initial={saved}/>);expect(screen.getByLabelText('Good response').getAttribute('aria-pressed')).toBe('true');
 fireEvent.click(screen.getByLabelText('Bad response'));await screen.findByLabelText('Feedback reason');
 fireEvent.change(screen.getByLabelText('Feedback reason'),{target:{value:'incomplete'}});
 fireEvent.change(screen.getByLabelText('Optional feedback comment'),{target:{value:'Missing one'}});
 fireEvent.click(screen.getByText('Save details'));
 await waitFor(()=>expect(api).toHaveBeenLastCalledWith('actor','/response-feedback/exact-message',expect.objectContaining({body:{rating:-1,reason:'incomplete',comment:'Missing one',expected_revision:2}})));
});
it('user prompt has only copy retry and a semantic timestamp',()=>{
 const retry=jest.fn();render(<MessageActions role="user" content="Prompt" timestamp="2026-10-25T20:00:00Z" onRetry={retry}/>);
 expect(screen.queryByLabelText('Good response')).toBeNull();expect(screen.queryByLabelText('Edit prompt')).toBeNull();fireEvent.click(screen.getByLabelText('Retry prompt'));
 expect(retry).toHaveBeenCalledTimes(1);expect(document.querySelector('time')?.dateTime).toBe('2026-10-25T20:00:00.000Z');
});
it('completed responses can be rated while retry is disabled for another running answer',async()=>{
 api.mockResolvedValue(saved);render(<MessageActions accountId="actor" messageId="exact-message" role="assistant" content="Answer" timestamp="2026-10-25T20:00:00Z" onRetry={()=>{}} retryDisabled/>);
 expect((screen.getByLabelText('Retry response') as HTMLButtonElement).disabled).toBe(true);
 fireEvent.click(screen.getByLabelText('Good response'));await waitFor(()=>expect(api).toHaveBeenCalledTimes(1));
});
it('copy falls back after clipboard rejection and restores focus',async()=>{
 Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:jest.fn().mockRejectedValue(new Error('denied'))}});
 document.execCommand=jest.fn().mockReturnValue(true);
 const button=document.createElement('button');document.body.appendChild(button);button.focus();
 await copyMessage('The exact response');expect(document.execCommand).toHaveBeenCalledWith('copy');expect(document.activeElement).toBe(button);expect(document.querySelector('textarea')).toBeNull();button.remove();
});
it('copy does not report success if neither browser method succeeds',async()=>{
 Object.defineProperty(navigator,'clipboard',{configurable:true,value:undefined});document.execCommand=jest.fn().mockReturnValue(false);
 render(<Harness/>);fireEvent.click(screen.getByLabelText('Copy message'));expect((await screen.findByRole('alert')).textContent).toContain("Couldn't copy");expect(screen.queryByLabelText('Copied')).toBeNull();
});
it('does not accept a receipt for another response',async()=>{
 api.mockResolvedValue({...saved,message_id:'wrong'});render(<Harness/>);fireEvent.click(screen.getByLabelText('Good response'));await screen.findByRole('alert');
 expect(screen.getByLabelText('Good response').getAttribute('aria-pressed')).toBe('false');
});
